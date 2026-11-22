import fs from 'node:fs';
import { createPrivateKey, randomBytes } from 'node:crypto';
import { readEnvironment } from './environment.mjs';

// Never print values: this audit handles the ignored production profile only.
const file = new URL('../.env.production', import.meta.url);
const env = readEnvironment('production');
const native = JSON.parse(fs.readFileSync(new URL('../flutter/android/app/google-services.json', import.meta.url)));
const android = native.client.find(c => c.client_info.android_client_info.package_name === 'com.example.yalla_5roga');
const db = URL.parse(env.DATABASE_URL ?? '');
const results = {
  databaseDashboardTarget: db?.hostname.replace(/-pooler(?=\.)/, '') === 'ep-misty-glitter-av3zwlzf.c-11.us-east-1.aws.neon.tech' && db?.pathname === '/neondb',
  databaseExpectedHost: env.EXPECTED_DATABASE_HOST === db?.hostname.replace(/-pooler(?=\.)/, ''),
  databaseExpectedName: env.EXPECTED_DATABASE_NAME === db?.pathname.slice(1),
  databaseTLS: ['require', 'verify-ca', 'verify-full'].includes(db?.searchParams.get('sslmode')),
  firebaseProject: env.FIREBASE_PROJECT_ID === native.project_info.project_id && env.EXPECTED_FIREBASE_PROJECT_ID === env.FIREBASE_PROJECT_ID,
  firebaseAndroidApp: env.FIREBASE_ANDROID_APP_ID === android?.client_info.mobilesdk_app_id,
  firebaseAndroidKey: android?.api_key.some(k => k.current_key === env.FIREBASE_ANDROID_API_KEY),
  firebaseSender: env.FIREBASE_MESSAGING_SENDER_ID === native.project_info.project_number,
  firebaseWebOAuth: android?.oauth_client?.some(c => c.client_type === 3 && c.client_id === env.FIREBASE_WEB_CLIENT_ID),
  firebaseAdminEmail: env.FIREBASE_CLIENT_EMAIL?.endsWith(`@${env.FIREBASE_PROJECT_ID}.iam.gserviceaccount.com`),
  firebasePrivateKey: false,
};
try { results.firebasePrivateKey = createPrivateKey(env.FIREBASE_PRIVATE_KEY?.replace(/\\n/g, '\n')).asymmetricKeyType === 'rsa'; } catch {}
if (process.argv.includes('--configure-defaults')) {
  const defaults = {
    MONITORING_TOKEN: randomBytes(32).toString('hex'),
    GRAFANA_ADMIN_PASSWORD: randomBytes(32).toString('base64url'),
    OBSERVABILITY_ENABLED: 'true', OBS_LOG_FORMAT: 'json', LOG_LEVEL: 'info', OBS_HTTP_LOG_SAMPLE: '0',
    IMAGE_UPLOAD_MAX_EDGE: '1600', IMAGE_UPLOAD_TARGET_BYTES: '358400', IMAGE_UPLOAD_QUALITY: '80',
    MEDIA_MAX_UPLOAD_BYTES: '10485760', MEDIA_UPLOAD_URL_TTL_SECONDS: '900', MEDIA_SIGNED_URL_TTL_SECONDS: '300',
    MEDIA_CLEANUP_INTERVAL_MS: '3600000', MEDIA_ALLOWED_MIME_TYPES: 'image/jpeg,image/png,image/webp,image/gif',
  };
  let text = fs.readFileSync(file, 'utf8');
  const configured = [];
  for (const [key, value] of Object.entries(defaults)) {
    if (env[key]?.trim()) continue;
    const pattern = new RegExp(`^${key}=.*$`, 'm');
    const line = `${key}=${JSON.stringify(value)}`;
    text = pattern.test(text) ? text.replace(pattern, () => line) : `${text}\n${line}\n`;
    configured.push(key);
  }
  fs.writeFileSync(file, text);
  console.log(JSON.stringify({ configured }));
}
console.log(JSON.stringify(results));
const plist = fs.readFileSync(new URL('../flutter/ios/Runner/GoogleService-Info.plist', import.meta.url), 'utf8');
const iosValue = key => plist.match(new RegExp(`<key>${key}</key>\\s*<string>([^<]*)</string>`))?.[1];
console.log(JSON.stringify({ iosProject: iosValue('PROJECT_ID') === env.FIREBASE_PROJECT_ID,
  iosApp: iosValue('GOOGLE_APP_ID') === env.FIREBASE_IOS_APP_ID,
  iosKey: iosValue('API_KEY') === env.FIREBASE_IOS_API_KEY,
  iosBundle: iosValue('BUNDLE_ID') === env.FIREBASE_IOS_BUNDLE_ID,
  iosOAuthClient: iosValue('CLIENT_ID') === env.FIREBASE_IOS_CLIENT_ID }));
if (process.argv.includes('--inventory')) {
  const references = new Map();
  function scan(directory) {
    for (const entry of fs.readdirSync(directory, { withFileTypes: true })) {
      const path = `${directory}/${entry.name}`;
      if (entry.isDirectory()) scan(path);
      else if (/\.(ts|dart|mjs)$/.test(entry.name)) {
        const source = fs.readFileSync(path, 'utf8');
        for (const match of source.matchAll(/(?:process\.env|env|settings)\.([A-Z][A-Z0-9_]*)|(?:fromEnvironment|envInt|env|setting)\(\s*['"]([A-Z][A-Z0-9_]*)['"]/g)) {
          const key = match[1] ?? match[2];
          const files = references.get(key) ?? new Set(); files.add(path); references.set(key, files);
        }
      }
    }
  }
  for (const dir of ['backend/src', 'flutter/lib', 'scripts']) scan(dir);
  const rows = [...new Set([...Object.keys(env), ...references.keys()])].sort().map(key =>
    `| ${key} | ${env[key]?.trim() ? 'Set' : 'Empty / source default'} | ${[...(references.get(key) ?? [])].join(', ') || 'Profile/launcher, dynamic lookup, or optional operator setting'} |`);
  fs.writeFileSync(new URL('../docs/audit/PRODUCTION_ENVIRONMENT_VARIABLES.md', import.meta.url),
    '# Production variable inventory\n\nRecorded 2026-11-22. Values are deliberately omitted. Set does not establish validity. Dynamic lookups require the environment reference and owning configuration module.\n\n| Variable | Local status | Source references |\n| --- | --- | --- |\n' + rows.join('\n') + '\n');
  console.log(JSON.stringify({ inventoriedVariables: rows.length }));
}
if (process.argv.includes('--remote-readonly')) {
  const { createRequire } = await import('node:module');
  const require = createRequire(new URL('../backend/package.json', import.meta.url));
  const { Client } = require('pg');
  const client = new Client({ connectionString: env.DATABASE_URL, connectionTimeoutMillis: 15000, statement_timeout: 10000 });
  try {
    await client.connect();
    await client.query('BEGIN READ ONLY');
    const response = await client.query('SELECT current_database() AS name');
    console.log(JSON.stringify({ neonReadOnlyConnection: response.rows[0]?.name === env.EXPECTED_DATABASE_NAME }));
    await client.query('ROLLBACK');
  } catch (error) { console.log(JSON.stringify({ neonReadOnlyConnection: false, code: error.code ?? 'connection_failed' })); }
  finally { await client.end().catch(() => {}); }
  try {
    const { cert } = require('firebase-admin/app');
    const credential = cert({ projectId: env.FIREBASE_PROJECT_ID, clientEmail: env.FIREBASE_CLIENT_EMAIL, privateKey: env.FIREBASE_PRIVATE_KEY.replace(/\\n/g, '\n') });
    const token = await credential.getAccessToken();
    console.log(JSON.stringify({ firebaseAdminTokenExchange: Boolean(token.access_token) }));
    const response = await fetch(`https://identitytoolkit.googleapis.com/admin/v2/projects/${env.FIREBASE_PROJECT_ID}/config`, { headers: { Authorization: `Bearer ${token.access_token}` }, signal: AbortSignal.timeout(15000) });
    if (response.ok) {
      const config = await response.json();
      console.log(JSON.stringify({ firebaseAuthConfigRead: true, phoneEnabled: config.signIn?.phoneNumber?.enabled ?? null }));
    } else console.log(JSON.stringify({ firebaseAuthConfigRead: false, status: response.status }));
  } catch { console.log(JSON.stringify({ firebaseAdminTokenExchange: false })); }
}
