import http from 'k6/http';
import { check, fail, sleep } from 'k6';
import { Counter, Trend } from 'k6/metrics';
import exec from 'k6/execution';

const base = (__ENV.API_BASE_URL || 'http://127.0.0.1:3000').replace(/\/$/, '');
if (!/^http:\/\/(127\.0\.0\.1|localhost):\d+$/.test(base)) {
  throw new Error('Use a localhost API backed by disposable PostgreSQL test data');
}
const presets = {
  baseline: { executor: 'constant-vus', vus: 1, duration: '45s' },
  concurrent: { executor: 'constant-vus', vus: 10, duration: '1m' },
  load: { executor: 'constant-vus', vus: 25, duration: '3m' },
  stress: { executor: 'ramping-vus', startVUs: 1, stages: [
    { duration: '45s', target: 10 }, { duration: '1m', target: 25 },
    { duration: '1m', target: 50 }, { duration: '1m', target: 100 }, { duration: '30s', target: 0 },
  ] },
  spike: { executor: 'ramping-vus', startVUs: 1, stages: [
    { duration: '30s', target: 10 }, { duration: '5s', target: 100 },
    { duration: '30s', target: 100 }, { duration: '5s', target: 10 },
    { duration: '45s', target: 10 }, { duration: '10s', target: 0 },
  ] },
  sustained: { executor: 'constant-vus', vus: 50, duration: '15m' },
  authentication: { executor: 'constant-vus', vus: 1, duration: '1m' },
};
const mode = __ENV.LOAD_SCENARIO || 'baseline';
const scenario = presets[mode];
if (!scenario) throw new Error('Unknown LOAD_SCENARIO');
const vu = __ENV.VUS ? Number(__ENV.VUS) : scenario.vus;
if (vu && ![1, 10, 25, 50, 100].includes(vu)) throw new Error('VUS must be 1, 10, 25, 50 or 100');
if (mode === 'authentication' && vu !== 1) throw new Error('Authentication uses one VU to respect credential throttling');

export const options = {
  scenarios: { [mode]: scenario.executor === 'constant-vus' ? { ...scenario, vus: vu, duration: __ENV.DURATION || scenario.duration } : scenario },
  discardResponseBodies: true,
  summaryTrendStats: ['count', 'med', 'p(95)', 'p(99)', 'max'],
  systemTags: ['status', 'method', 'name', 'scenario', 'expected_response'],
  thresholds: {
    ...(mode === 'baseline' ? {
      'http_req_failed{scenario:baseline}': ['rate<0.01'],
      'http_req_duration{scenario:baseline}': ['p(95)<500', 'p(99)<1000'],
    } : {}),
    workflow_assertion_failures: ['count==0'],
  },
};

const rejected = new Counter('workflow_assertion_failures');
const latencies = Object.fromEntries([
  ['POST /api/auth/login', 'login'], ['POST /api/users/sync', 'user_sync'],
  ['GET /api/groups/cuser', 'groups'], ['GET /api/outings/cuser', 'outings'],
  ['GET /api/places/recommendations', 'recommendations'], ['GET /api/groups/:id', 'group'],
  ['GET /api/groups/:id/members', 'group_members'], ['GET /api/outings/:id', 'outing'],
  ['GET /api/outings/:id/voting-state', 'voting_state'], ['GET /api/places', 'places'],
  ['GET /api/places/geojson', 'viewport'], ['GET /api/notifications', 'notifications'],
  ['GET /api/outings/:outingId/messages', 'chat_history'], ['POST /api/outings/:outingId/messages', 'chat_send'],
].map(([route, name]) => [route, new Trend('api_' + name, true)]));
export function setup() {
  if (__ENV.ALLOW_DISPOSABLE_LOAD !== '1' || !__ENV.MONITORING_TOKEN) {
    fail('Set ALLOW_DISPOSABLE_LOAD=1 and supply the local monitoring credential');
  }
  const response = http.get(base + '/health/dependencies', {
    headers: { Authorization: 'Bearer ' + __ENV.MONITORING_TOKEN },
    responseType: 'text',
    tags: { name: 'GET /health/dependencies' },
  });
  if (response.status !== 200 || response.json('isolatedTestTarget') !== true) {
    fail('The backend could not verify a disposable loopback PostgreSQL target');
  }
  if (mode === 'authentication') {
    if (!__ENV.FIXTURE_PHONE || !__ENV.FIXTURE_PASSWORD) fail('Provide a dedicated synthetic login account');
  } else if (!__ENV.FIXTURE_TOKENS || !__ENV.FIXTURE_GROUP || !__ENV.FIXTURE_OUTING) {
    fail('Provide fixture tokens, group and outing IDs for the isolated load server');
  }
}

function request(method, route, {token, path = route, body, status = 200, keepBody = false} = {}) {
  const response = http.request(method, base + path, body === undefined ? null : JSON.stringify(body), {
    headers: { ...(token ? { Authorization: 'Bearer ' + token } : {}), 'Content-Type': 'application/json',
      'X-Client-Source': 'internal', 'X-Request-Trigger': 'background_sync' },
    tags: { name: method + ' ' + route },
    responseType: keepBody ? 'text' : 'none',
    timeout: '15s',
  });
  const identity = method + ' ' + route;
  if (!check(response, { [identity + ' expected status']: r => r.status === status })) rejected.add(1);
  else latencies[identity]?.add(response.timings.duration);
  return response;
}

export default function () {
  if (mode === 'authentication') {
    const login = request('POST', '/api/auth/login', {
      body: { phone: __ENV.FIXTURE_PHONE, password: __ENV.FIXTURE_PASSWORD }, keepBody: true,
    });
    if (login.status === 200) {
      request('POST', '/api/users/sync', { token: login.json('data.idToken'), body: {} });
    }
    sleep(6);
    return;
  }
  const tokens = __ENV.FIXTURE_TOKENS.split(',');
  const token = tokens[(exec.vu.idInTest - 1) % tokens.length];
  const group = encodeURIComponent(__ENV.FIXTURE_GROUP);
  const outing = encodeURIComponent(__ENV.FIXTURE_OUTING);
  const authenticated = { token };
  switch (exec.vu.iterationInScenario % 5) {
    case 0:
      request('GET', '/api/groups/cuser', authenticated);
      request('GET', '/api/outings/cuser', authenticated);
      request('GET', '/api/places/recommendations', { path: '/api/places/recommendations?limit=8' });
      break;
    case 1:
      request('GET', '/api/groups/:id', { token, path: '/api/groups/' + group });
      request('GET', '/api/groups/:id/members', { token, path: '/api/groups/' + group + '/members' });
      break;
    case 2:
      request('GET', '/api/outings/:id', { token, path: '/api/outings/' + outing });
      request('GET', '/api/outings/:id/voting-state', { token, path: '/api/outings/' + outing + '/voting-state' });
      break;
    case 3:
      request('GET', '/api/places', { path: '/api/places?search=coffee&limit=20' });
      request('GET', '/api/places/geojson', { path: '/api/places/geojson?bbox=31.20,30.01,31.26,30.07&limit=30' });
      request('GET', '/api/notifications', { token, path: '/api/notifications?limit=20' });
      break;
    default:
      request('GET', '/api/outings/:outingId/messages', { token, path: '/api/outings/' + outing + '/messages?limit=25' });
      if (__ENV.WRITE_FIXTURES === '1') {
        const clientId = '00000000-0000-4000-8000-' +
          (exec.vu.idInTest * 100000000 + exec.vu.iterationInScenario).toString().padStart(12, '0');
        request('POST', '/api/outings/:outingId/messages', {
          token, path: '/api/outings/' + outing + '/messages', status: 201,
          body: { text: 'Synthetic load fixture', clientMessageId: clientId },
        });
      }
  }
  sleep(Number(__ENV.THINK_SECONDS || 1));
}
