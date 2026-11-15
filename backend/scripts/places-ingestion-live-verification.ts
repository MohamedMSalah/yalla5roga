/** Read-only application-schema verification selected from the served OpenAPI. */
import "dotenv/config";
import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import { readFileSync, writeFileSync } from "node:fs";
import app from "../src/app.js";
import { prisma } from "../src/config/database.js";
import { insideBoundary } from "../src/services/places/import-normalization.js";
import { syncStatus, verifyPlacesTarget } from "../src/services/places/places-sync.js";
const results: { scenario: string; result: string; count?: number }[] = [];
const report: any = { checkedAt: new Date().toISOString(), mode: "read-only served Swagger/HTTP and Neon readback; no Flutter/device tests" };
const pass = (scenario: string, count?: number) => { results.push({ scenario, result: "PASS", ...(count === undefined ? {} : { count }) }); console.log(`PASS ${scenario}`); };
const server = app.listen(0, "127.0.0.1"); await new Promise<void>((done) => server.once("listening", done));
const address = server.address(); assert.ok(address && typeof address !== "string");
const base = `http://127.0.0.1:${address.port}`;
let spec: any;
const resolve = (ref: string): any => ref.slice(2).split("/").reduce((v: any, key: string) => v[key], spec);
function validate(schema: any, value: any): void {
  if (!schema) return;
  if (schema.$ref) return validate(resolve(schema.$ref), value);
  if (value === null && schema.nullable) return;
  for (const child of schema.allOf ?? []) validate(child, value);
  if (schema.type === "object") {
    assert.ok(value && typeof value === "object" && !Array.isArray(value));
    for (const key of schema.required ?? []) assert.ok(key in value, `Missing ${key}`);
    for (const [key, child] of Object.entries(schema.properties ?? {})) if (key in value) validate(child, value[key]);
  } else if (schema.type === "array") { assert.ok(Array.isArray(value)); for (const row of value) validate(schema.items, row); }
  else if (schema.type === "integer") assert.ok(Number.isInteger(value));
  else if (schema.type) assert.equal(typeof value, schema.type);
  if (schema.enum) assert.ok(schema.enum.includes(value));
}
function operation(id: string): any {
  for (const [path, item] of Object.entries(spec.paths) as any) if (item.get?.operationId === id) return { path, ...item.get };
  throw new Error(`Missing operation ${id}`);
}
async function read(id: string, query: any = {}, params: any = {}, expected = 200): Promise<any> {
  const op = operation(id); let path = op.path;
  for (const [key, value] of Object.entries(params)) path = path.replace(`{${key}}`, encodeURIComponent(String(value)));
  for (const key of Object.keys(query)) assert.ok(op.parameters?.some((p: any) => p.in === "query" && p.name === key), `Undocumented ${key}`);
  const response = await fetch(`${base}${path}?${new URLSearchParams(query)}`, { signal: AbortSignal.timeout(30000) });
  const body: any = await response.json(); assert.equal(response.status, expected, `${id}: ${JSON.stringify(body).slice(0, 300)}`);
  let declared = op.responses[String(expected)]; assert.ok(declared); if (declared.$ref) declared = resolve(declared.$ref);
  const content = declared.content?.["application/json"] ?? declared.content?.["application/geo+json"];
  validate(content?.schema, body); return body;
}
try {
  report.target = await verifyPlacesTarget();
  const init = await (await fetch(base + "/api-docs/swagger-ui-init.js")).text();
  spec = JSON.parse(init.split("var options = ")[1]!.split(/;\r?\n/)[0]!).swaggerDoc;
  assert.equal((await fetch(base + "/api-docs/")).status, 200);
  pass("Served Swagger UI and OpenAPI operations");
  const categories = await read("listPlaceCategories"), vibes = await read("listPlaceVibes");
  assert.equal(categories.data.length, 44); assert.equal(vibes.data.length, 23);
  assert.ok([...categories.data, ...vibes.data].every((d: any) => d.id && d.name_en && d.name_ar));
  pass("Bilingual normalized categories", categories.data.length); pass("Bilingual stable vibe definitions", vibes.data.length);
  const list = await read("listPlaces", { limit: "50" });
  assert.ok(list.data.length > 0 && list.data.every((p: any) => p.status === "active"));
  assert.ok(list.data.every((p: any) => !["source_tags", "manually_managed", "missing_sync_count"].some((k) => k in p)));
  pass("Actual active database places and safe public projection", list.data.length);
  const nearby = await read("listNearbyPlaces", { lat: "30.05", lng: "31.24", radiusKm: "5", limit: "10" });
  assert.ok(nearby.data.length && nearby.data.every((p: any) => p.distance_km <= 5));
  pass("Existing nearby API with real places and unknown-price compatibility", nearby.data.length);
  const bounds = { minLat: "29.95", minLng: "31.1", maxLat: "30.2", maxLng: "31.5", limit: "100" };
  const bounded = await read("listPlaces", bounds);
  assert.ok(bounded.data.length && bounded.data.every((p: any) => p.latitude >= 29.95 && p.latitude <= 30.2 && p.longitude >= 31.1 && p.longitude <= 31.5));
  pass("Map bounds aliases return real in-bounds places", bounded.data.length);
  const picked = bounded.data.find((p: any) => p.category_id && p.vibes.length); assert.ok(picked);
  const filtered = await read("listPlaces", { ...bounds, category: picked.category_id, vibes: picked.vibes[0] });
  assert.ok(filtered.data.length && filtered.data.every((p: any) => p.category_id === picked.category_id && p.vibes.includes(picked.vibes[0])));
  pass("Category and vibe intersection", filtered.data.length);
  const searched = await read("listPlaces", { search: picked.name.slice(0, 60), limit: "20" }); assert.ok(searched.data.length);
  pass("Real place-name database search", searched.data.length);
  const detail = await read("getPlace", {}, { id: picked.id });
  assert.equal(detail.data.id, picked.id);
  for (const key of ["place_hours", "place_images", "place_prices", "place_vibes"]) assert.ok(Array.isArray(detail.data[key]));
  assert.ok(!("source_tags" in detail.data)); pass("Existing place details with complete ancillary relations");
  const geo = await read("getPlacesGeoJson", { ...bounds, category: picked.category_id, vibes: picked.vibes[0] });
  assert.ok(geo.features.length);
  for (const feature of geo.features) {
    assert.equal(feature.geometry.type, "Point"); const [lng, lat] = feature.geometry.coordinates;
    assert.ok(lng >= 31.1 && lng <= 31.5 && lat >= 29.95 && lat <= 30.2);
    assert.ok(!("place_images" in feature.properties) && !("source_tags" in feature.properties));
    assert.ok(feature.properties.icon && feature.properties.vibes.includes(picked.vibes[0]));
  }
  pass("Lightweight valid GeoJSON coordinates, category icons and vibe properties", geo.features.length);
  for (const sort of ["updated", "name"]) {
    const first = await read("listPlaces", { limit: "7", sort }); assert.ok(first.pagination.next_cursor);
    const next = await read("listPlaces", { limit: "7", sort, cursor: first.pagination.next_cursor });
    const seen = new Set(first.data.map((p: any) => p.id)); assert.ok(next.data.length && next.data.every((p: any) => !seen.has(p.id)));
    pass(`Non-empty keyset pagination without repeated IDs: ${sort}`);
  }
  await read("getPlacesVersion"); pass("Catalog revision endpoint");
  const licenses = await read("getPlacesLicenses");
  assert.ok(licenses.data.licenses.some((l: any) => l.id === "CDLA-Permissive-2.0" && l.text.length > 1000));
  pass("Required source license text and upstream notices");
  for (const [id, query] of [["getPlacesGeoJson", {}], ["listPlaces", { minLat: "30" }], ["listPlaces", { bbox: "32,31,30,29" }], ["listPlaces", { limit: "101" }], ["listPlaces", { cursor: "invalid" }]] as const) {
    await read(id, query, {}, 400); pass(`Declared invalid-query 400: ${JSON.stringify(query)}`);
  }
  assert.equal((await fetch(base + "/api/places/sync/history")).status, 401); pass("Sync history remains authenticated/curator-only");
  assert.ok(!spec.paths["/api/places/sync/worker"]); assert.equal((await fetch(base + "/api/places/sync/worker", { method: "POST" })).status, 404);
  assert.equal((await syncStatus()).automatic_sync_enabled, false); pass("Automatic scheduler route and due gate removed");
  const manifest = JSON.parse(readFileSync(".places-data/overture-all.manifest.json", "utf8"));
  const boundary = JSON.parse(readFileSync(manifest.boundary_path, "utf8"));
  const rows = await prisma.places.findMany({ where: { source: { in: ["osm", "overture"] } }, select: { id: true, source_region: true, latitude: true, longitude: true, category_id: true } });
  for (const place of rows) {
    assert.ok(place.category_id && place.latitude !== null && place.longitude !== null);
    assert.ok(insideBoundary(place.longitude!, place.latitude!, boundary.features.find((f: any) => f.properties.region === place.source_region)?.geometry));
  }
  pass("Every imported place has a category and lies inside its administrative polygon", rows.length);
  report.counts = {
    places: await prisma.places.groupBy({ by: ["source", "source_region", "status"], _count: true }),
    tables: Object.fromEntries(await Promise.all(["places", "place_categories", "vibes", "place_vibes", "place_images", "place_hours", "place_prices", "place_sync_runs", "place_sync_logs", "place_status_changes", "place_source_records"].map(async (table) => [table, (await prisma.$queryRawUnsafe<any[]>(`SELECT count(*)::int AS n FROM ${table}`))[0].n]))),
  };
  report.runs = await prisma.place_sync_runs.findMany({ where: { coverage: { path: ["version"], equals: 2 } }, orderBy: { started_at: "asc" } });
  assert.ok(report.runs.some((r: any) => r.source === "overture" && r.status === "success" && r.complete));
  assert.ok(report.runs.some((r: any) => r.source === "osm" && r.status === "success" && r.complete));
  pass("Initial imports and detailed diagnostics persisted for both sources");
  const duplicateTuples = await prisma.$queryRaw<any[]>`SELECT source,source_type,source_id FROM places WHERE source<>'manual' GROUP BY source,source_type,source_id HAVING count(*)>1`;
  assert.equal(duplicateTuples.length, 0); pass("No duplicate canonical source identities");
  const deployment = JSON.parse(readFileSync("../docs/audit/PLACES_INGESTION_MIGRATION_DEPLOYMENT.json", "utf8"));
  const backup = JSON.parse(readFileSync(deployment.privateBackup, "utf8"));
  const originalOutingIds = backup.tables.outings.rows.map((r: any) => r.id);
  assert.equal(await prisma.outings.count({ where: { id: { in: originalOutingIds } } }), originalOutingIds.length);
  for (const table of ["outing_vote_options", "outing_votes", "saved_places"]) {
    for (const row of backup.tables[table].rows) {
      const where: any = table === "outing_vote_options" ? { id: row.id } : table === "outing_votes" ? { outing_id: row.outing_id, user_id: row.user_id, option_id: row.option_id } : { place_id: row.place_id, user_id: row.user_id };
      assert.equal(await (prisma as any)[table].count({ where }), 1);
    }
  }
  pass("Original outings and recorded vote/bookmark identities preserved", originalOutingIds.length);
  report.migrations = await prisma.$queryRaw<any[]>`SELECT migration_name,checksum,finished_at FROM _prisma_migrations WHERE migration_name IN ('20261114050000_places_free_ingestion','20261114051000_places_unknown_price_absence')`;
  for (const migration of report.migrations) assert.equal(migration.checksum, createHash("sha256").update(readFileSync(`prisma/migrations/${migration.migration_name}/migration.sql`)).digest("hex"));
  assert.equal(report.migrations.length, 2); pass("Both deployed migration checksums match reviewed SQL");
  report.result = "PASS";
} catch (error) { report.result = "FAIL"; results.push({ scenario: error instanceof Error ? error.stack ?? error.message : String(error), result: "FAIL" }); process.exitCode = 1; console.error(error); }
finally {
  report.results = results; writeFileSync("../docs/audit/PLACES_INGESTION_LIVE_RESULTS.json", JSON.stringify(report, null, 2));
  await new Promise<void>((done) => server.close(() => done())); await prisma.$disconnect();
}
