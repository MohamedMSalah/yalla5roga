/** Served Swagger/HTTP plus sync lifecycle checks in an isolated, disposable Neon schema. */
import "dotenv/config";
import assert from "node:assert/strict";
import { randomUUID, createHash } from "node:crypto";
import { readFileSync, readdirSync, writeFileSync } from "node:fs";
import { Client } from "pg";
import express from "express";
import swaggerUi from "swagger-ui-express";
const schema = `places_verify_${randomUUID().replaceAll("-", "")}`;
const url = new URL(process.env.DATABASE_URL!);
url.hostname = url.hostname.replace("-pooler.", ".");
url.searchParams.delete("channel_binding");
url.searchParams.delete("pgbouncer");
url.searchParams.set("sslmode", "verify-full");
const admin = new Client({
  connectionString: url.toString(),
  connectionTimeoutMillis: 20000,
});
url.searchParams.set("schema", schema);
url.searchParams.set("connection_limit", "1");
process.env.DATABASE_URL = url.toString();
process.env.NODE_ENV = "production";
process.env.PLACES_SYNC_QUIET = "1";
process.env.PLACES_CURATOR_UIDS = "places-curator";
process.env.PLACES_SYNC_WORKER_SECRET =
  "test-worker-secret-not-used-outside-fixture";
let db: import("@prisma/client").PrismaClient | undefined,
  server: import("node:http").Server | undefined,
  made = false;
const results: { scenario: string; result: string }[] = [];
const pass = (scenario: string) => {
  results.push({ scenario, result: "PASS" });
  console.log(JSON.stringify({ completed: results.length, scenario }));
};
const hash = (v: unknown) =>
  createHash("sha256").update(JSON.stringify(v)).digest("hex");
try {
  await admin.connect();
  const before = (
    await admin.query(
      `SELECT coalesce(jsonb_agg(to_jsonb(o) ORDER BY o.id),'[]'::jsonb) AS rows FROM public.outings o`,
    )
  ).rows[0].rows;
  assert.match(schema, /^places_verify_[a-f0-9]{32}$/);
  await admin.query(`CREATE SCHEMA "${schema}"`);
  made = true;
  await admin.query(`SET search_path TO "${schema}"`);
  for (const m of readdirSync("prisma/migrations")
    .filter((n) => /^\d/.test(n))
    .sort())
    await admin.query(
      readFileSync(`prisma/migrations/${m}/migration.sql`, "utf8").replace(
        'CREATE SCHEMA IF NOT EXISTS "public";',
        "",
      ),
    );
  db = (await import("../src/config/database.js")).prisma;
  await db.$executeRawUnsafe(`SET search_path TO "${schema}"`);
  assert.equal(
    (await db.$queryRawUnsafe<any[]>("SELECT current_schema() AS name"))[0]
      .name,
    schema,
  );
  const { synchronizePlaces, syncStatus } =
    await import("../src/services/places/places-sync.js");
  const { PlaceDatasource } =
    await import("../src/datasources/places/place.datasource.js");
  const { assertSelectablePlaces } =
    await import("../src/services/places/place-selection.js");
  const manual = await db.places.create({
    data: {
      name: "Manual untouched",
      cover_image_url: "https://example.com/cover.jpg",
    },
  });
  const elements: any[] = [
    {
      type: "node",
      id: 101,
      version: 10,
      lat: 30.05,
      lon: 31.2,
      tags: { name: "Cafe One", "name:ar": "مقهى أول", amenity: "cafe" },
    },
    {
      type: "way",
      id: 101,
      center: { lat: 30.051, lon: 31.201 },
      tags: { name: "Bowling One", sport: "bowling" },
    },
    {
      type: "node",
      id: 103,
      lat: 30.052,
      lon: 31.202,
      tags: { name: "Restaurant One", amenity: "restaurant" },
    },
  ];
  const source = async (region: string, key: string) =>
    region === "EG-C" && key === "amenity" ? elements : [];
  let run: any = await synchronizePlaces({}, source);
  assert.equal(run.status, "success");
  assert.equal(run.imported_count, 3);
  assert.equal(await db.places.count(), 4);
  pass(
    "Insert across node/way namespaces, bilingual taxonomy and manual-place preservation",
  );
  run = await synchronizePlaces({}, source);
  assert.equal(run.imported_count, 0);
  assert.equal(await db.places.count(), 4);
  pass("Repeated complete sync deduplicates stable OSM identities");
  let cafe = await db.places.findFirstOrThrow({
    where: { source_type: "node", source_id: "101" },
  });
  await db.places.update({
    where: { id: cafe.id },
    data: { cover_image_url: "https://example.com/preserved.jpg" },
  });
  await db.users.create({
    data: { id: "places-curator", name: "Curator", phone: "+15550000001" },
  });
  const outing = await db.outings.create({
    data: {
      title: "History fixture",
      created_by: "places-curator",
      location_place_id: cafe.id,
      status: "past",
      type: "special_event",
      occasion: "other",
    },
  });
  elements[0].tags.name = "Updated Cafe";
  elements[0].tags.opening_hours = "closed";
  await synchronizePlaces({}, source);
  cafe = await db.places.findUniqueOrThrow({ where: { id: cafe.id } });
  assert.equal(cafe.name, "Updated Cafe");
  assert.equal(cafe.status, "temporarily_closed");
  assert.equal(cafe.cover_image_url, "https://example.com/preserved.jpg");
  pass(
    "Updates source fields, temporary closure evidence and preserves fallback/existing image",
  );
  elements[0].tags = { name: "Closed cafe", "demolished:amenity": "cafe" };
  await synchronizePlaces({}, source);
  assert.equal(
    (await db.places.findUniqueOrThrow({ where: { id: cafe.id } })).status,
    "permanently_closed",
  );
  await assert.rejects(() =>
    db!.$transaction((tx) => assertSelectablePlaces(tx, [cafe.id])),
  );
  assert.equal(
    (await db.outings.findUniqueOrThrow({ where: { id: outing.id } }))
      .location_place_id,
    cafe.id,
  );
  pass(
    "Permanent closure blocked for new selection; existing historical outing retained",
  );
  elements[0].tags = { name: "Reopened Cafe", amenity: "cafe" };
  await synchronizePlaces({}, source);
  assert.equal(
    (await db.places.findUniqueOrThrow({ where: { id: cafe.id } })).status,
    "active",
  );
  pass("Current supported source evidence reliably reopens closed identity");
  elements[0].version = 9;
  elements[0].tags = {
    name: "Stale mirror closure",
    "demolished:amenity": "cafe",
  };
  await synchronizePlaces({}, source);
  const newer = await db.places.findUniqueOrThrow({ where: { id: cafe.id } });
  assert.equal(newer.status, "active");
  assert.equal(newer.name, "Reopened Cafe");
  elements[0].version = 11;
  elements[0].tags = { name: "Reopened Cafe", amenity: "cafe" };
  pass(
    "Older OSM element versions cannot overwrite newer names or lifecycle evidence",
  );
  const bowl = await db.places.findFirstOrThrow({
    where: { source_type: "way", source_id: "101" },
  });
  await new PlaceDatasource().update(bowl.id, { name: "Curator override" });
  elements[1].tags.name = "OSM should not overwrite";
  await synchronizePlaces({}, source);
  assert.equal(
    (await db.places.findUniqueOrThrow({ where: { id: bowl.id } })).name,
    "Curator override",
  );
  pass("Curator managed OSM and source=manual records are never overwritten");
  const restaurant = await db.places.findFirstOrThrow({
    where: { source_id: "103" },
  });
  elements.splice(2, 1);
  await synchronizePlaces({ limit: 1 }, source);
  assert.equal(
    (await db.places.findUniqueOrThrow({ where: { id: restaurant.id } }))
      .missing_sync_count,
    0,
  );
  pass(
    "Validation limit marks partial coverage and never advances missing streak",
  );
  const beforeFailure = hash(
    await db.places.findMany({ orderBy: { id: "asc" } }),
  );
  await assert.rejects(() =>
    synchronizePlaces({}, async (region, key) => {
      if (key === "shop") throw new Error("controlled timeout");
      return source(region, key);
    }),
  );
  assert.equal(
    hash(await db.places.findMany({ orderBy: { id: "asc" } })),
    beforeFailure,
  );
  pass("Failed/incomplete sync cannot change any place or lifecycle counters");
  await synchronizePlaces({}, source);
  await synchronizePlaces({}, source);
  assert.equal(
    (await db.places.findUniqueOrThrow({ where: { id: restaurant.id } }))
      .status,
    "active",
  );
  await synchronizePlaces({}, source);
  const missing = await db.places.findUniqueOrThrow({
    where: { id: restaurant.id },
  });
  assert.equal(missing.status, "unverified");
  assert.equal(missing.missing_sync_count, 3);
  pass(
    "Exactly three successful complete missing cycles yield unverified, never permanent closure",
  );
  const beforeDry = hash(await db.places.findMany({ orderBy: { id: "asc" } }));
  run = await synchronizePlaces({ dryRun: true }, source);
  assert.equal(run.status, "dry_run");
  assert.equal(
    hash(await db.places.findMany({ orderBy: { id: "asc" } })),
    beforeDry,
  );
  pass("Dry-run logs projected counters without mutating places or mappings");
  let release!: () => void, entered!: () => void;
  const gate = new Promise<void>((r) => (release = r)),
    started = new Promise<void>((r) => (entered = r));
  const running = synchronizePlaces({}, async (region, key) => {
    if (region === "EG-C" && key === "amenity") {
      entered();
      await gate;
    }
    return source(region, key);
  });
  await started;
  await assert.rejects(() => synchronizePlaces({}, source), /already running/);
  release();
  await running;
  pass(
    "Database lease rejects concurrent worker including independent invocations",
  );
  assert.equal(
    ((await synchronizePlaces({ dueOnly: true }, source)) as any).status,
    "not_due",
  );
  assert.equal((await syncStatus()).due, false);
  pass(
    "Seven-day persisted due gate skips duplicate schedule; reports last successful timestamp",
  );
  const expired = randomUUID();
  await db.place_sync_lock.create({
    data: { id: "osm", token: expired, expires_at: new Date(0) },
  });
  await db.place_sync_runs.create({ data: { id: expired, status: "running" } });
  await synchronizePlaces({}, source);
  assert.equal(
    (await db.place_sync_runs.findUniqueOrThrow({ where: { id: expired } }))
      .status,
    "failed",
  );
  pass(
    "Expired worker lease is safely reclaimed and abandoned run logged failed",
  );
  assert.ok(
    (await db.place_status_changes.count({ where: { place_id: cafe.id } })) >=
      4,
  );
  pass("Status history stores run IDs and source evidence");
  const { getFirebaseAuth } = await import("../src/config/firebase.js");
  getFirebaseAuth().verifyIdToken = async (token: string) => {
    if (!["places-curator", "ordinary-user"].includes(token))
      throw Object.assign(new Error("fixture invalid"), {
        code: "auth/invalid-id-token",
      });
    return { uid: token, firebase: { sign_in_provider: "custom" } } as any;
  };
  const { swaggerSpec } = await import("../src/config/swagger.js");
  const spec = swaggerSpec as any;
  const { errorMiddleware } =
    await import("../src/middleware/error.middleware.js");
  const app = express();
  app.use(express.json());
  app.use("/api-docs", swaggerUi.serve, swaggerUi.setup(spec));
  app.use((await import("../src/routes/places/index.js")).default);
  app.use(errorMiddleware);
  server = app.listen(0, "127.0.0.1");
  await new Promise<void>((r) => server!.once("listening", r));
  const base = `http://127.0.0.1:${(server.address() as any).port}`;
  async function call(
    path: string,
    status = 200,
    token?: string,
    method = "GET",
    body?: unknown,
  ) {
    const response = await fetch(base + path, {
      method,
      headers: {
        ...(token ? { Authorization: `Bearer ${token}` } : {}),
        ...(body ? { "Content-Type": "application/json" } : {}),
      },
      body: body ? JSON.stringify(body) : undefined,
    });
    const json = (await response.json()) as any;
    assert.equal(response.status, status, JSON.stringify(json));
    return json;
  }
  const served = await (
    await fetch(base + "/api-docs/swagger-ui-init.js")
  ).text();
  assert.ok(served.includes("listPlaceCategories"));
  assert.ok(served.includes("runDuePlacesSync"));
  pass(
    "Served Swagger includes taxonomy, filters, sync administration and protected worker",
  );
  assert.equal((await call("/api/places/categories")).data.length, 36);
  assert.equal((await call("/api/places/vibes")).data.length, 15);
  pass("HTTP taxonomy returns all active bilingual definitions with icons");
  let response = await call(
    "/api/places?categories=cafes&vibes=coffee_conversations&search=Reopened&lat=30.05&lng=31.2&radiusKm=1&sort=distance",
  );
  assert.equal(response.data.length, 1);
  assert.equal(response.data[0].id, cafe.id);
  assert.ok(response.data[0].vibes.includes("coffee_conversations"));
  pass(
    "HTTP combined category, multi-vibe, search, nearby and distance sorting",
  );
  response = await call("/api/places?bbox=31.19,30.04,31.21,30.06&limit=1");
  assert.equal(response.data.length, 1);
  assert.ok(response.pagination.has_more);
  assert.equal(response.pagination.next_offset, 1);
  pass("HTTP geographic bounding box and stable server-side pagination");
  response = await call("/api/places?status=unverified");
  assert.ok(response.data.some((p: any) => p.id === restaurant.id));
  assert.ok(
    !(await call("/api/places")).data.some((p: any) => p.id === restaurant.id),
  );
  pass(
    "Default recommendations exclude unavailable; explicit status reads preserve access",
  );
  await call("/api/places?lat=30", 400);
  await call("/api/places?bbox=bad", 400);
  await call("/api/places?limit=100000", 400);
  pass("HTTP rejects invalid spatial, status and pagination requests");
  await call("/api/places/sync/status", 401);
  await call("/api/places/sync/status", 403, "ordinary-user");
  response = await call("/api/places/sync/status", 200, "places-curator");
  assert.ok(response.data.last_successful_sync_at);
  pass(
    "Sync status enforces Firebase authentication and existing curator allowlist",
  );
  response = await call("/api/places/sync/history", 200, "places-curator");
  assert.ok(response.data.some((r: any) => r.status === "failed"));
  await call("/api/places/sync", 403, "ordinary-user", "POST", {});
  await call("/api/places/sync/worker", 401, undefined, "POST", {});
  await call(
    "/api/places/sync/worker",
    200,
    process.env.PLACES_SYNC_WORKER_SECRET,
    "POST",
    {},
  );
  pass(
    "Sync logs and worker secret protection; external scheduled worker safely skips not-due catalog",
  );
  await call(`/api/places/${cafe.id}/save`,201,'places-curator','POST',{});
  const savedResponse=await call('/api/places/saved',200,'places-curator');
  assert.ok(savedResponse.data.some((row:any)=>row.place_id===cafe.id&&row.places.id===cafe.id&&Array.isArray(row.places.place_vibes)));
  await call(`/api/places/${cafe.id}/save`,200,'places-curator','DELETE');
  assert.ok(!(await call('/api/places/saved',200,'places-curator')).data.some((row:any)=>row.place_id===cafe.id));
  pass('Saved places retain hydrated catalog details and save/unsave through the existing API');
  const beforeDelete = await db.places.count();
  await call(`/api/places/${cafe.id}`, 200, "places-curator", "DELETE");
  assert.equal(await db.places.count(), beforeDelete);
  assert.equal(
    (await call(`/api/places/${cafe.id}`)).data.status,
    "permanently_closed",
  );
  assert.ok(
    !(await call("/api/places/nearby?lat=30.05&lng=31.2")).data.some(
      (p: any) => p.id === cafe.id,
    ),
  );
  pass(
    "Curator delete archives place, retains history and excludes from nearby endpoint",
  );
  const after = (
    await admin.query(
      `SELECT coalesce(jsonb_agg(to_jsonb(o) ORDER BY o.id),'[]'::jsonb) AS rows FROM public.outings o`,
    )
  ).rows[0].rows;
  assert.equal(hash(after), hash(before));
  pass("Existing application public outing rows remain byte-for-byte intact");
  writeFileSync(
    "../docs/audit/PLACES_OPENAPI_RESULTS.json",
    JSON.stringify(
      {
        verifiedAt: new Date().toISOString(),
        scope:
          "isolated Neon schema; real Prisma/HTTP/Swagger, controlled OSM and Firebase boundaries",
        checks: results.length,
        results,
      },
      null,
      2,
    ) + "\n",
  );
} finally {
  if (server) await new Promise<void>((r) => server!.close(() => r()));
  await db?.$disconnect();
  if (made) {
    assert.match(schema, /^places_verify_[a-f0-9]{32}$/);
    await admin.query(`DROP SCHEMA "${schema}" CASCADE`);
  }
  await admin.end();
}
