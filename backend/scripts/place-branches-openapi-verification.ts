/** Served Swagger/HTTP verification. All writes stay in a generated disposable
 * schema. Only Firebase verification and official artifact acquisition are controlled. */
import assert from "node:assert/strict";
import { createHash, randomUUID } from "node:crypto";
import { mkdirSync, readFileSync, readdirSync, writeFileSync } from "node:fs";
import { resolve } from "node:path";
import { pathToFileURL } from "node:url";
import { Client } from "pg";
import express from "express";
import swaggerUi from "swagger-ui-express";

// Local-only by default. Neon mode requires separately authorized disposable-schema access.
const local = !process.argv.includes("--neon-disposable");
let localDb: any, localServer: any;
let localConnection = "";
if (local) {
  const moduleAt = (path: string) => pathToFileURL(resolve(".places-data/branch-verification/node_modules", path)).href;
  const { PGlite } = await import(moduleAt("@electric-sql/pglite/dist/index.js"));
  const { PGLiteSocketServer } = await import(moduleAt("@electric-sql/pglite-socket/dist/index.js"));
  localDb = await PGlite.create();
  await localDb.exec("SET neon.project_id='local-fixture'; SET neon.branch_id='local-fixture'");
  localServer = new PGLiteSocketServer({ db: localDb, host: "127.0.0.1", port: 0, maxConnections: 2 });
  await localServer.start();
  localConnection = `postgresql://postgres:postgres@${localServer.getServerConn()}/postgres`;
}
const schema = `branches_verify_${randomUUID().replaceAll("-", "")}`;
const url = new URL(local ? localConnection : process.env.DATABASE_URL!);
url.hostname = url.hostname.replace("-pooler.", ".");
for (const key of ["channel_binding", "pgbouncer"]) url.searchParams.delete(key);
url.searchParams.set("sslmode", local ? "disable" : "verify-full");
const admin = new Client({ connectionString: url.toString(), connectionTimeoutMillis: 20000 });
url.searchParams.set("schema", schema); url.searchParams.set("connection_limit", "1");
process.env.DATABASE_URL = url.toString(); process.env.NODE_ENV = "production";
process.env.PLACES_CURATOR_UIDS = "branches-fixture-owner";
let db: any, server: any, made = false, fixtureManifest = "";
const results: any[] = [];
const pass = (scenario: string) => { results.push({ scenario, result: "PASS" }); console.log(`PASS ${scenario}`); };
const hash = (s: string) => createHash("sha256").update(s).digest("hex");
const directory = resolve(".places-data", schema);
try {
  await admin.connect();
  const target = (await admin.query("SELECT current_database() AS database,current_setting('neon.project_id',true) AS project,current_setting('neon.branch_id',true) AS branch")).rows[0];
  assert.equal(target.project, local ? "local-fixture" : "rough-mountain-69896781");
  assert.equal(target.branch, local ? "local-fixture" : "br-fragrant-heart-avfm4h2t");
  process.env.PLACES_EXPECTED_TARGET = JSON.stringify({ ...target, schema });
  await admin.query(`CREATE SCHEMA "${schema}"`); made = true;
  await admin.query(`SET search_path TO "${schema}"`);
  for (const m of readdirSync("prisma/migrations").filter((n) => /^\d/.test(n) && n < "20261115000000_place_brands").sort())
    await admin.query(readFileSync(`prisma/migrations/${m}/migration.sql`, "utf8").replace('CREATE SCHEMA IF NOT EXISTS "public";', ""));
  const legacy = randomUUID(), legacyOuting = randomUUID(), owner = "branches-fixture-owner";
  await admin.query("INSERT INTO users(id,name,phone) VALUES ($1,'Fixture owner','+15550009001')", [owner]);
  await admin.query("INSERT INTO places(id,name,latitude,longitude) VALUES ($1,'Independent legacy',30,31.4)", [legacy]);
  await admin.query("INSERT INTO outings(id,title,created_by,type,occasion,status,scheduled_at,location_place_id) VALUES ($1,'Legacy event',$2,'special_event','other','confirmed',now()+interval '2 days',$3)", [legacyOuting, owner, legacy]);
  const migration = readFileSync("prisma/migrations/20261115000000_place_brands/migration.sql", "utf8");
  await admin.query(migration); await admin.query(migration);
  db = (await import("../src/config/database.js")).prisma;
  await db.$executeRawUnsafe(`SET search_path TO "${schema}"`);
  assert.equal((await db.$queryRawUnsafe("SELECT current_schema() AS name"))[0].name, schema);
  pass("Additive migration applies twice; disposable schema isolated from application data");

  mkdirSync(directory, { recursive: true });
  const boundary = resolve(directory, "boundary.geojson");
  writeFileSync(boundary, JSON.stringify({ type: "FeatureCollection", features: [{ properties: { region: "EG-C" }, geometry: {
    type: "Polygon", coordinates: [[[31,29],[32,29],[32,31],[31,31],[31,29]]],
  } }] }));
  function manifest(records: any[], release: string) {
    const file = resolve(directory, "fixture.ndjson"), meta = resolve(directory, "fixture.manifest.json");
    const data = records.map((record) => JSON.stringify({ region: "EG-C", record })).join("\n") + "\n";
    writeFileSync(file, data); writeFileSync(meta, JSON.stringify({ source: "overture", city: "cairo", complete: true,
      release, path: file, boundary_path: boundary, records: { "EG-C": records.length }, sha256: hash(data),
      boundary_sha256: hash(readFileSync(boundary, "utf8")), fetched_at: new Date().toISOString() }));
    fixtureManifest = meta;
  }
  const { CatalogUseCase } = await import("../src/usecases/places/catalog.usecase.js");
  const catalog = new CatalogUseCase();
  const { synchronizePlaces } = await import("../src/services/places/places-sync.js");
  // The HTTP sync contract stays unchanged; source acquisition resolves a fixture artifact.
  catalog.sync = (options) => synchronizePlaces({ ...options, manifest: fixtureManifest });
  const { CatalogController } = await import("../src/controllers/places/catalog.controller.js");
  const { PlaceController } = await import("../src/controllers/places/place.controller.js");
  const { createAuthMiddleware } = await import("../src/middleware/auth.middleware.js");
  const { UnauthorizedError } = await import("../src/utils/errors.js");
  const { requirePlaceCurator } = await import("../src/middleware/place-curator.middleware.js");
  const { validate } = await import("../src/middleware/validate.middleware.js");
  const validators = await import("../src/validators/places/place.validator.js");
  const { errorMiddleware } = await import("../src/middleware/error.middleware.js");
  const { swaggerSpec } = await import("../src/config/swagger.js");
  const auth = createAuthMiddleware(async (token) => {
    if (![owner, "branches-fixture-reader"].includes(token)) throw new UnauthorizedError();
    return { uid: token };
  });
  const app = express(), places = new PlaceController();
  app.use(express.json()); app.use("/api-docs", swaggerUi.serve, swaggerUi.setup(swaggerSpec));
  app.post("/api/places/sync", auth, requirePlaceCurator, new CatalogController(catalog).sync);
  app.post("/api/places", auth, requirePlaceCurator, validate({ body: validators.createPlaceBodySchema }), places.create);
  app.patch("/api/places/:id", auth, requirePlaceCurator, validate({ params: validators.placeIdParamsSchema, body: validators.updatePlaceBodySchema }), places.update);
  app.use((await import("../src/routes/places/index.js")).default);
  app.use("/api/outings", auth, (await import("../src/routes/outings/outing.crud.routes.js")).default);
  app.use(errorMiddleware);
  server = app.listen(0, "127.0.0.1"); await new Promise<void>((done) => server.once("listening", done));
  const base = `http://127.0.0.1:${server.address().port}`;
  const init = await (await fetch(base + "/api-docs/swagger-ui-init.js")).text();
  const spec = JSON.parse(init.split("var options = ")[1]!.split(/;\r?\n/)[0]!).swaggerDoc;
  const operations = new Map<string, any>();
  for (const [path, item] of Object.entries(spec.paths) as any) for (const [method, op] of Object.entries(item) as any)
    if (op.operationId) operations.set(op.operationId, { path, method, ...op });
  async function call(id: string, { params = {}, query = {}, body, status = 200, token }: any = {}) {
    const op = operations.get(id); assert.ok(op, `Swagger operation ${id}`);
    const path = op.path.replace(/\{(\w+)\}/g, (_: string, k: string) => params[k]);
    const response = await fetch(`${base}${path}?${new URLSearchParams(query)}`, {
      method: op.method.toUpperCase(), headers: { ...(token ? { Authorization: `Bearer ${token}` } : {}),
        ...(body ? { "Content-Type": "application/json" } : {}) }, body: body ? JSON.stringify(body) : undefined,
      signal: AbortSignal.timeout(120000),
    });
    const json: any = await response.json();
    assert.equal(response.status, status, `${id}: ${JSON.stringify(json)}`);
    assert.ok(op.responses[String(status)], `${id} documents ${status}`);
    return json;
  }
  pass("Served Swagger resolves all HTTP operation paths and documented statuses");
  const rows = [0,1,2].map((n) => ({ id: randomUUID(), names: { primary: "Buffalo Burger", common: { ar: "بافلو برجر", en: "Buffalo Burger" } },
    brand: { names: { primary: "Buffalo Burger", common: { ar: "بافلو برجر", en: "Buffalo Burger" } }, wikidata: "Q990000001" },
    addresses: [{ freeform: `${10+n} Fixture Street`, locality: ["Maadi","Nasr City","Giza"][n], country: "EG" }],
    basic_category: "restaurant", confidence: .95, operating_status: "open", latitude: 30+n*.02, longitude: 31.2+n*.03,
    version: 1, sources: [{ dataset: "fixture", license: "CDLA-Permissive-2.0" }] }));
  async function sync(release: string, records = rows) {
    manifest(records, release); return (await call("syncPlaces", { token: owner, body: { source: "overture", city: "cairo" } })).data;
  }
  await sync("fixture-1");
  let branches = (await call("listPlaces", { query: { search: "Buffalo", sort: "name" } })).data;
  assert.equal(branches.length, 3); const brand = branches[0].brand_id;
  assert.ok(brand); assert.equal(new Set(branches.map((p: any) => p.brand_id)).size, 1);
  assert.equal(new Set(branches.map((p: any) => p.id)).size, 3);
  assert.equal(new Set(branches.map((p: any) => `${p.latitude},${p.longitude}`)).size, 3);
  assert.equal(await db.place_brands.count(), 1);
  pass("Scenarios 1–3: import three physical branches, one bilingual brand, distinct IDs and coordinates");
  const original = branches.map((p: any) => p.id).sort();
  const repeat = await sync("fixture-1"); assert.equal(repeat.inserted, 0); assert.equal(repeat.updated, 0);
  assert.deepEqual((await call("listPlaceBrandBranches", { params: { id: brand } })).data.map((p: any) => p.id).sort(), original);
  pass("Scenario 4: identical import preserves branch IDs without duplicate brands or branches");
  rows.push({ ...rows[0]!, id: randomUUID(), names: { primary: "بافلو برجر", common: { ar: "بافلو برجر", en: "Buffalo Burger" } },
    brand: { names: { primary: "بافلو برجر", common: { ar: "بافلو برجر", en: "Buffalo Burger" } }, wikidata: "Q990000001" },
    addresses: [{ freeform: "40 Fixture Road", locality: "New Cairo", country: "EG" }], latitude: 30.12, longitude: 31.5 });
  await sync("fixture-2");
  branches = (await call("listPlaceBrandBranches", { params: { id: brand } })).data;
  assert.equal(branches.length, 4); assert.equal((await call("getPlaceBrand", { params: { id: brand } })).data.branch_count, 4);
  assert.equal(await db.place_brands.count(), 1);
  pass("Scenario 5: fourth Arabic-named branch resolves the same brand through bilingual source evidence");
  const selected = branches.find((p: any) => p.source_id === rows[0]!.id);
  const unchanged = branches.filter((p: any) => p.id !== selected.id);
  rows[0]!.addresses[0]!.freeform = "99 Updated Road"; rows[0]!.version = 2;
  await sync("fixture-3");
  assert.equal((await call("getPlace", { params: { id: selected.id } })).data.address, "99 Updated Road");
  for (const other of unchanged) assert.equal((await call("getPlace", { params: { id: other.id } })).data.updated_at, other.updated_at);
  pass("Scenario 6: updating one branch leaves all sibling timestamps and data unchanged");
  const outing = (await call("createOuting", { token: owner, status: 201, body: { title: "Branch outing", occasion: "other", vote_deadline_hours: 3,
    scheduled_at: new Date(Date.now()+86400000).toISOString(), location_place_id: selected.id,
    location_name: selected.name, location_latitude: selected.latitude, location_longitude: selected.longitude, create_request_key: randomUUID() } })).data;
  assert.equal(outing.location_place_id, selected.id);
  rows[0]!.operating_status = "permanently_closed"; rows[0]!.version = 3; await sync("fixture-4");
  assert.equal((await call("getPlace", { params: { id: selected.id } })).data.status, "permanently_closed");
  assert.equal((await call("getPlaceBrand", { params: { id: brand } })).data.branch_count, 3);
  assert.equal(await db.place_status_changes.count({ where: { place_id: selected.id, new_status: "permanently_closed" } }), 1);
  assert.equal((await call("getOuting", { token: owner, params: { id: outing.id } })).data.location_place_id, selected.id);
  assert.equal((await call("getOuting", { token: owner, params: { id: legacyOuting } })).data.location_place_id, legacy);
  pass("Scenarios 7–9: branch-only closure preserves its brand, siblings, new outing and pre-migration outing references");
  const page = await call("listPlaceBrandBranches", { params: { id: brand }, query: { limit: "1", lat: "30", lng: "31.2", sort: "distance" } });
  assert.equal(page.data.length, 1); assert.ok(page.pagination.has_more);
  const next = await call("listPlaceBrandBranches", { params: { id: brand }, query: { limit: "1", lat: "30", lng: "31.2", sort: "distance", cursor: page.pagination.next_cursor } });
  assert.notEqual(next.data[0].id, page.data[0].id);
  const nearby = (await call("listNearbyPlaces", { query: { lat: "30.02", lng: "31.23", radiusKm: "50", brand_id: brand } })).data;
  assert.ok(nearby.length); assert.ok(nearby.every((p: any) => p.brand_id === brand && p.branch_id === p.id && p.status === "active"));
  for (const p of nearby) for (const key of ["brand_name","branch_name","branch_count","category","vibes","latitude","longitude"])
    assert.ok(key in p, `Consistent DTO: ${key}`);
  await call("getPlaceBrand", { params: { id: randomUUID() }, status: 404 });
  await call("getPlaceBrand", { params: { id: "invalid" }, status: 400 });
  await call("syncPlaces", { body: { dryRun: true }, status: 401 });
  await call("syncPlaces", { token: "branches-fixture-reader", body: { dryRun: true }, status: 403 });
  await call("createPlace", { token: owner, body: { name: "Invalid physical place" }, status: 400 });
  const manualBody = { name: "Curated fourth", branch_name: "Downtown", brand_id: brand, latitude: 30.05, longitude: 31.3, source_id: "fixture-curator-1", address: "50 Fixture Avenue" };
  const manual = (await call("createPlace", { token: owner, status: 201, body: manualBody })).data;
  const replay = (await call("createPlace", { token: owner, status: 201, body: manualBody })).data;
  assert.equal(manual.id, replay.id); assert.equal(manual.brand_id, brand);
  assert.equal(manual.brand_name, "Buffalo Burger");
  pass("Scenario 10: Swagger/HTTP DTOs, brand filter, nearest-first pagination, validation, auth/curator gates and idempotent curator creation");
} catch (error) {
  results.push({ scenario: "Verification", result: "FAIL", reason: error instanceof Error ? error.message : "Unknown failure" });
  console.error(error instanceof Error ? error.message : "Verification failed"); process.exitCode = 1;
} finally {
  if (server) await new Promise<void>((done) => server.close(() => done()));
  await db?.$disconnect();
  if (made) { assert.match(schema, /^branches_verify_[a-f0-9]{32}$/); await admin.query(`DROP SCHEMA "${schema}" CASCADE`); }
  await admin.end();
  await localServer?.stop(); await localDb?.close();
  writeFileSync("../docs/audit/PLACE_BRANCHES_OPENAPI_RESULTS.json", JSON.stringify({ checkedAt: new Date().toISOString(),
    engine: local ? "Local PGlite PostgreSQL/WASM" : "Neon disposable schema",
    mode: "Served Swagger/HTTP; disposable schema; controlled Firebase verifier and artifact acquisition; no workers, Flutter runtime or production writes",
    cleanup: made ? "Disposable schema removed" : "No schema created", results }, null, 2)+"\n");
}
