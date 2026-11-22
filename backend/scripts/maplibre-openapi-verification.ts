/** Read-only HTTP verification, selected exclusively from served Swagger/OpenAPI. */
import assert from 'node:assert/strict';
import { writeFileSync } from 'node:fs';
import app from '../src/app.js';
import { prisma } from '../src/config/database.js';

const results: Array<{ scenario: string; result: string; status?: number; count?: number }> = [];
const pass = (scenario: string, extra = {}) => results.push({ scenario, result: 'PASS', ...extra });
const server = app.listen(0, '127.0.0.1');
await new Promise<void>(done => server.once('listening', done));
const address = server.address();
assert.ok(address && typeof address !== 'string');
const base = `http://127.0.0.1:${address.port}`;
let spec: any;
const resolve = (ref: string): any => ref.slice(2).split('/').reduce((v: any, key: string) => v[key], spec);
function validate(schema: any, value: any): void {
  if (!schema) return;
  if (schema.$ref) return validate(resolve(schema.$ref), value);
  if (value === null && schema.nullable) return;
  for (const child of schema.allOf ?? []) validate(child, value);
  if (schema.type === 'object') {
    assert.ok(value && typeof value === 'object' && !Array.isArray(value));
    for (const key of schema.required ?? []) assert.ok(key in value, `Missing ${key}`);
    for (const [key, child] of Object.entries(schema.properties ?? {})) if (key in value) validate(child, value[key]);
  } else if (schema.type === 'array') { assert.ok(Array.isArray(value)); for (const row of value) validate(schema.items, row); }
  else if (schema.type === 'integer') assert.ok(Number.isInteger(value));
  else if (schema.type) assert.equal(typeof value, schema.type);
  if (schema.enum) assert.ok(schema.enum.includes(value));
}
function operation(id: string): any {
  for (const [url, path] of Object.entries(spec.paths) as any) {
    const op = path.get;
    if (op?.operationId === id) return { url, ...op };
  }
  throw Error(`Missing GET operation ${id}`);
}
async function read(id: string, query: Record<string, string> = {}, params: Record<string, string> = {}, expected = 200): Promise<any> {
  const op = operation(id);
  let url = op.url;
  for (const [key, value] of Object.entries(params)) url = url.replace(`{${key}}`, encodeURIComponent(value));
  for (const key of Object.keys(query)) assert.ok(op.parameters?.some((p: any) => p.in === 'query' && p.name === key), `${id}: undocumented ${key}`);
  const response = await fetch(`${base}${url}?${new URLSearchParams(query)}`, { signal: AbortSignal.timeout(20000) });
  const body = await response.json();
  assert.equal(response.status, expected, `${id}: expected ${expected}, got ${response.status}`);
  let declared = op.responses[String(expected)];
  assert.ok(declared, `${id}: undocumented response ${expected}`);
  if (declared.$ref) declared = resolve(declared.$ref);
  validate(declared.content?.['application/json']?.schema, body);
  return body;
}
try {
  const ui = await fetch(base + '/api-docs/'); assert.equal(ui.status, 200);
  const init = await (await fetch(base + '/api-docs/swagger-ui-init.js')).text();
  const options = init.split('var options = ')[1]?.split(/;\r?\n/)[0]; assert.ok(options);
  spec = JSON.parse(options).swaggerDoc;
  pass('Served Swagger UI and OpenAPI document', { status: 200 });
  const list = operation('listPlaces');
  for (const field of ['bbox', 'categories', 'vibes', 'search', 'status', 'sort', 'limit', 'offset']) {
    assert.ok(list.parameters.some((p: any) => p.in === 'query' && p.name === field));
    pass(`Existing catalog query contract: ${field}`);
  }
  for (const field of ['id', 'name', 'category_id', 'vibes', 'latitude', 'longitude', 'cover_image_url', 'status']) {
    assert.ok(spec.components.schemas.Place.properties[field]);
  }
  pass('Place contract includes all database marker fields');
  const categories = await read('listPlaceCategories');
  const vibes = await read('listPlaceVibes');
  pass('Bilingual category definitions and icon tokens', { count: categories.data.length });
  pass('Bilingual vibe definitions', { count: vibes.data.length });
  await read('getPlacesVersion'); pass('Catalog revision read');
  const page = await read('listPlaces', { status: 'active', limit: '5', offset: '0', sort: 'name' });
  assert.ok(page.data.length <= 5); assert.ok(page.data.every((p: any) => p.status === 'active'));
  assert.equal(page.pagination.limit, 5); assert.equal(page.pagination.offset, 0);
  pass('Active catalog GET and pagination envelope (empty rows are retained honestly)', { count: page.data.length });
  if (page.pagination.has_more) {
    const next = await read('listPlaces', { status: 'active', limit: '5', offset: String(page.pagination.next_offset), sort: 'name' });
    const ids = new Set(page.data.map((p: any) => p.id));
    assert.ok(next.data.every((p: any) => !ids.has(p.id)));
    pass('Next page uses server next_offset without duplicates', { count: next.data.length });
  } else results.push({ scenario: 'Non-empty next-page HTTP verification requires active catalog rows', result: 'NOT_RUN' });
  const bounded = await read('listPlaces', { bbox: '31.1,29.95,31.4,30.15', status: 'active', limit: '50' });
  assert.ok(bounded.data.every((p: any) => p.longitude >= 31.1 && p.longitude <= 31.4 && p.latitude >= 29.95 && p.latitude <= 30.15 && p.status === 'active'));
  pass('Cairo viewport GET and active/bounds checks on returned rows', { count: bounded.data.length });
  const place = bounded.data.find((p: any) => p.category_id && p.vibes?.length) ?? bounded.data.find((p: any) => p.category_id);
  if (place) {
    const query: Record<string, string> = { bbox: '31.1,29.95,31.4,30.15', categories: place.category_id, status: 'active', limit: '50' };
    if (place.vibes?.length) query.vibes = place.vibes[0];
    const filtered = await read('listPlaces', query);
    assert.ok(filtered.data.length > 0);
    assert.ok(filtered.data.every((p: any) => p.category_id === place.category_id && (!query.vibes || p.vibes.includes(query.vibes))));
    pass('Viewport combines category and vibe filters', { count: filtered.data.length });
    const detail = await read('getPlace', {}, { id: place.id });
    assert.equal(detail.data.id, place.id); pass('Pin ID resolves through existing place details API');
    const search = await read('listPlaces', { search: place.name.slice(0, 20), status: 'active', limit: '5' });
    assert.ok(search.data.length > 0); pass('Database name search retains catalog response contract');
  } else results.push({ scenario: 'Filtered/detail/search HTTP checks require a categorized place in the viewport', result: 'NOT_RUN' });
  for (const [name, query] of [
    ['reversed bounds', { bbox: '32,31,30,29' }],
    ['invalid page size', { limit: '101' }],
    ['invalid offset', { offset: '-1' }],
    ['invalid category', { categories: 'not-a-real-category' }],
  ] as const) { await read('listPlaces', query, {}, 400); pass(`Swagger-declared validation: ${name}`, { status: 400 }); }
} catch (error) {
  results.push({ scenario: error instanceof Error ? error.message : 'Verification failed', result: 'FAIL' });
  process.exitCode = 1;
} finally {
  writeFileSync('../docs/audit/MAPLIBRE_OPENAPI_RESULTS.json', JSON.stringify({ checkedAt: new Date().toISOString(), mode: 'read-only served Swagger/OpenAPI HTTP; no fixtures, migrations or Flutter execution', results }, null, 2) + '\n');
  await new Promise<void>(done => server.close(() => done()));
  await prisma.$disconnect();
}
console.log(JSON.stringify({ passed: results.filter(r => r.result === 'PASS').length, results }, null, 2));
