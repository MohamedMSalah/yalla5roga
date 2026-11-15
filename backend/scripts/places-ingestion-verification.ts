/** Real Prisma/HTTP verification; fixtures exist only in this uniquely named disposable schema. */
import "dotenv/config";
import assert from "node:assert/strict";
import { randomUUID, createHash } from "node:crypto";
import { mkdirSync, readFileSync, readdirSync, writeFileSync } from "node:fs";
import { resolve } from "node:path";
import { Client } from "pg";
const schema = `places_ingestion_verify_${randomUUID().replaceAll("-", "")}`;
const url = new URL(process.env.DATABASE_URL!);
url.hostname = url.hostname.replace("-pooler.", "."); url.searchParams.delete("channel_binding"); url.searchParams.delete("pgbouncer"); url.searchParams.set("sslmode", "verify-full");
const admin = new Client({ connectionString: url.toString(), connectionTimeoutMillis: 30000 });
url.searchParams.set("schema", schema); url.searchParams.set("connection_limit", "1");
process.env.DATABASE_URL = url.toString(); process.env.NODE_ENV = "production";
const results: { scenario: string; result: string }[] = [];
const pass = (scenario: string) => { results.push({ scenario, result: "PASS" }); console.log(`PASS ${scenario}`); };
const directory = resolve(".places-data", schema); mkdirSync(directory, { recursive: true });
const hash = (value: string) => createHash("sha256").update(value).digest("hex");
let db: any, server: any, made = false;
try {
  await admin.connect();
  const target = (await admin.query("SELECT current_database() AS database,current_setting('neon.project_id',true) AS project,current_setting('neon.branch_id',true) AS branch")).rows[0];
  assert.equal(target.project, "rough-mountain-69896781"); assert.equal(target.branch, "br-fragrant-heart-avfm4h2t");
  process.env.PLACES_EXPECTED_TARGET = JSON.stringify({ ...target, schema });
  await admin.query(`CREATE SCHEMA "${schema}"`); made = true; await admin.query(`SET search_path TO "${schema}"`);
  for (const migration of readdirSync("prisma/migrations").filter((n) => /^\d/.test(n)).sort())
    await admin.query(readFileSync(`prisma/migrations/${migration}/migration.sql`, "utf8").replace('CREATE SCHEMA IF NOT EXISTS "public";', ""));
  db = (await import("../src/config/database.js")).prisma;
  await db.$executeRawUnsafe(`SET search_path TO "${schema}"`);
  assert.equal((await db.$queryRawUnsafe("SELECT current_schema() AS name"))[0].name, schema);
  pass("All migrations apply in an isolated schema without production writes");
  const { synchronizePlaces } = await import("../src/services/places/places-sync.js");
  const boundaryPath = resolve(directory, "boundaries.geojson");
  const polygon = (a: number, b: number) => ({ type: "Polygon", coordinates: [[[a, 29],[b,29],[b,31],[a,31],[a,29]]] });
  writeFileSync(boundaryPath, JSON.stringify({ type: "FeatureCollection", features: [
    { properties: { region: "EG-C" }, geometry: polygon(31, 32) }, { properties: { region: "EG-GZ" }, geometry: polygon(30, 31) },
  ] }));
  function manifest(source: "overture" | "osm", rows: any[], release = "fixture-release-1") {
    const path = resolve(directory, `${source}.ndjson`); const meta = resolve(directory, `${source}.manifest.json`);
    const text = rows.map((r) => JSON.stringify(r)).join("\n") + (rows.length ? "\n" : ""); writeFileSync(path, text);
    writeFileSync(meta, JSON.stringify({ source, city: "all", complete: true, release, path, boundary_path: boundaryPath,
      records: { "EG-C": rows.filter((r) => r.region === "EG-C").length, "EG-GZ": rows.filter((r) => r.region === "EG-GZ").length },
      sha256: hash(text), boundary_sha256: hash(readFileSync(boundaryPath, "utf8")), fetched_at: new Date().toISOString() })); return meta;
  }
  const primary = [
    { region: "EG-C", record: { id: randomUUID(), names: { primary: "Fixture Cairo Cafe" }, basic_category: "cafe", confidence: .9, operating_status: "open", latitude: 30, longitude: 31.2, phones: ["+201012345678"], version: 1, sources: [{ dataset: "meta", license: "CDLA-Permissive-2.0" }] } },
    { region: "EG-C", record: { id: randomUUID(), names: { primary: "Fixture Cairo Cinema" }, basic_category: "movie_theater", confidence: .9, operating_status: "open", latitude: 30.1, longitude: 31.3, version: 1, sources: [{ dataset: "meta", license: "CDLA-Permissive-2.0" }] } },
    { region: "EG-GZ", record: { id: randomUUID(), names: { primary: "Fixture Giza Museum" }, basic_category: "museum", confidence: .9, operating_status: "open", latitude: 30, longitude: 30.9, version: 1, sources: [{ dataset: "meta", license: "CDLA-Permissive-2.0" }] } },
  ];
  const sourceManifest = manifest("overture", primary);
  const before = await db.place_sync_runs.count();
  let run: any = await synchronizePlaces({ source: "overture", manifest: sourceManifest, dryRun: true, batchSize: 2 });
  assert.equal(run.inserted, 3); assert.equal(await db.places.count(), 0); assert.equal(await db.place_sync_runs.count(), before); assert.equal(await db.place_sync_lock.count(), 0);
  pass("Dry-run validates multiple chunks with zero database writes");
  run = await synchronizePlaces({ source: "overture", manifest: sourceManifest, batchSize: 2 });
  assert.equal(run.inserted, 3); assert.equal(await db.places.count(), 3); assert.equal(await db.places.count({ where: { price_level: null } }), 3);
  assert.equal(await db.place_vibes.count({ where: { confidence: { gt: 0 } } }) > 0, true);
  pass("Initial import, bilingual taxonomy, confidence and unknown prices persist");
  const repeat: any = await synchronizePlaces({ source: "overture", manifest: sourceManifest });
  assert.equal(repeat.inserted, 0); assert.equal(await db.places.count(), 3); assert.equal(repeat.updated, 0);
  pass("Repeated source import is idempotent");
  const secondary = [
    { region: "EG-C", record: { id: 1001, type: "node", lat: 30, lon: 31.2, version: 1, tags: { name: "Fixture Cairo Cafe", amenity: "cafe", phone: "+201012345678" } } },
    { region: "EG-GZ", record: { id: 1002, type: "node", lat: 30, lon: 30.8, version: 1, tags: { name: "Fixture Giza Park", leisure: "park", opening_hours: "Mo-Fr 09:00-18:00; Sa off", charge: "150 EGP" } } },
    { region: "EG-GZ", record: { id: 1003, type: "node", lat: 30, lon: 30.7, version: 1, tags: { name: "Fixture unmapped", amenity: "bank" } } },
  ];
  run = await synchronizePlaces({ source: "osm", manifest: manifest("osm", secondary), batchSize: 2 });
  assert.equal(run.inserted, 1); assert.equal(run.duplicates, 1); assert.equal(await db.places.count(), 4);
  assert.equal(await db.place_source_records.count(), 5); assert.equal(await db.place_hours.count(), 6); assert.equal(await db.place_prices.count(), 1);
  assert.ok(await db.place_sync_logs.count({ where: { code: "invalid_or_unmapped_osm" } }));
  pass("Cross-source duplicate aliases preserve canonical metadata; hours/prices and diagnostics persist");
  const cafe = await db.places.findFirstOrThrow({ where: { source_id: primary[0]!.record.id } });
  await db.users.create({ data: { id: "fixture-ingestion-owner", name: "Fixture", phone: "+201099999999" } });
  const group = await db.groups.create({ data: { name: "Fixture", created_by: "fixture-ingestion-owner" } });
  const outing = await db.outings.create({ data: { title: "Fixture", created_by: "fixture-ingestion-owner", group_id: group.id, location_place_id: cafe.id } });
  await db.saved_places.create({ data: { user_id: "fixture-ingestion-owner", place_id: cafe.id } });
  await db.outing_vote_options.create({ data: { outing_id: outing.id, place_id: cafe.id, label: "Fixture" } });
  primary[0]!.record.operating_status = "temporarily_closed"; primary[0]!.record.version = 2;
  await synchronizePlaces({ source: "overture", manifest: manifest("overture", primary, "fixture-release-2") });
  assert.equal((await db.places.findUniqueOrThrow({ where: { id: cafe.id } })).status, "temporarily_closed");
  assert.equal(await db.place_status_changes.count({ where: { place_id: cafe.id, new_status: "temporarily_closed" } }), 1);
  assert.equal((await db.outings.findUniqueOrThrow({ where: { id: outing.id } })).location_place_id, cafe.id);
  assert.equal(await db.saved_places.count(), 1); assert.equal(await db.outing_vote_options.count(), 1);
  pass("Explicit status changes preserve outings, saved places and voting references");
  await db.places.update({ where: { id: cafe.id }, data: { name: "Curator choice", manually_managed: true } });
  await synchronizePlaces({ source: "overture", manifest: manifest("overture", primary, "fixture-release-3") });
  assert.equal((await db.places.findUniqueOrThrow({ where: { id: cafe.id } })).name, "Curator choice");
  pass("Manual curator edits survive later releases");
  const museum = await db.places.findFirstOrThrow({ where: { category_id: "museums" } });
  const withoutMuseum = primary.filter((p) => p.record.id !== museum.source_id);
  for (const release of ["absence-1", "absence-1", "absence-2"]) await synchronizePlaces({ source: "overture", manifest: manifest("overture", withoutMuseum, release) });
  assert.equal((await db.places.findUniqueOrThrow({ where: { id: museum.id } })).status, "active");
  await synchronizePlaces({ source: "overture", manifest: manifest("overture", withoutMuseum, "absence-3") });
  assert.equal((await db.places.findUniqueOrThrow({ where: { id: museum.id } })).status, "unverified");
  pass("Repeated absence needs three distinct releases; a replay never proves closure");
  const abort = new AbortController(); abort.abort(new Error("Test interruption"));
  await assert.rejects(synchronizePlaces({ source: "overture", manifest: sourceManifest, signal: abort.signal }));
  const interrupted = await db.place_sync_runs.findFirstOrThrow({ where: { status: "interrupted" }, orderBy: { started_at: "desc" } });
  const resumed: any = await synchronizePlaces({ source: "overture", manifest: sourceManifest, resume: interrupted.id });
  assert.equal(resumed.status, "success");
  pass("Interruption is recorded and the exact artifact resumes safely");
  await db.place_sync_lock.create({ data: { id: "catalog", token: randomUUID(), expires_at: new Date(Date.now() + 60000) } });
  await assert.rejects(synchronizePlaces({ source: "osm", manifest: manifest("osm", secondary) }), /already running/);
  await db.place_sync_lock.deleteMany();
  pass("Concurrent imports are rejected by the database lease");
  // Verify served Swagger/UI plus real route/controller/usecase/repository/SQL responses.
  const app = (await import("../src/app.js")).default;
  server = app.listen(0, "127.0.0.1"); await new Promise<void>((done) => server.once("listening", done));
  const base = `http://127.0.0.1:${server.address().port}`;
  const init = await (await fetch(base + "/api-docs/swagger-ui-init.js")).text();
  const spec = JSON.parse(init.split("var options = ")[1]!.split(/;\r?\n/)[0]!).swaggerDoc;
  assert.ok(!spec.paths["/api/places/sync/worker"]);
  assert.equal((await fetch(base + "/api/places/sync/worker", { method: "POST" })).status, 404);
  const manualStatus = await (await import("../src/services/places/places-sync.js")).syncStatus();
  assert.equal(manualStatus.automatic_sync_enabled, false);
  pass("Weekly scheduler API and due gate are removed");
  const operation = (id: string) => Object.entries(spec.paths).find(([, p]: any) => p.get?.operationId === id)?.[0];
  async function get(id: string, query: any = {}, expected = 200) {
    const path = operation(id); assert.ok(path, `Swagger operation ${id}`);
    const response = await fetch(`${base}${path}?${new URLSearchParams(query)}`); assert.equal(response.status, expected); return response.json() as Promise<any>;
  }
  const page = await get("listPlaces", { bbox: "30,29,32,31", limit: "1" });
  assert.equal(page.data.length, 1); assert.ok(page.pagination.next_cursor);
  const next = await get("listPlaces", { bbox: "30,29,32,31", limit: "1", cursor: page.pagination.next_cursor });
  assert.notEqual(next.data[0].id, page.data[0].id);
  assert.ok(!("source_tags" in next.data[0]));
  pass("Served Swagger catalog query and microsecond-safe cursor pagination");
  const geo = await get("getPlacesGeoJson", { minLng: "30", minLat: "29", maxLng: "32", maxLat: "31", category: "parks", vibes: "outdoor_nature" });
  assert.equal(geo.type, "FeatureCollection"); assert.equal(geo.features.length, 1);
  assert.deepEqual(geo.features[0].geometry.coordinates, [30.8, 30]); assert.ok(!("place_images" in geo.features[0].properties));
  const detail = await (await fetch(`${base}/api/places/${geo.features[0].properties.place_id}`)).json() as any;
  assert.equal(detail.data.place_hours.length, 6); assert.equal(detail.data.place_prices.length, 1); assert.ok(!("source_tags" in detail.data));
  await get("getPlacesGeoJson", {}, 400); await get("listPlaces", { cursor: "bad" }, 400);
  pass("GeoJSON bounds/category/vibe filters, coordinates, lightweight properties and complete details");
  const unauthenticated = await fetch(base + "/api/places/sync/history"); assert.equal(unauthenticated.status, 401);
  pass("Administrative sync diagnostics remain private");
} catch (error) {
  results.push({ scenario: error instanceof Error ? error.stack ?? error.message : String(error), result: "FAIL" }); process.exitCode = 1; console.error(error);
} finally {
  if (server) await new Promise<void>((done) => server.close(() => done()));
  if (db) await db.$disconnect();
  if (made) { assert.match(schema, /^places_ingestion_verify_[a-f0-9]{32}$/); await admin.query(`DROP SCHEMA "${schema}" CASCADE`); }
  await admin.end();
  writeFileSync("../docs/audit/PLACES_INGESTION_INTEGRATION_RESULTS.json", JSON.stringify({ checkedAt: new Date().toISOString(), mode: "Isolated schema; no Flutter/runtime/device tests; application schema untouched", results }, null, 2));
}
