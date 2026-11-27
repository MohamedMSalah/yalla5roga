/** Uses a new disposable database on a local PostgreSQL cluster. */
import assert from "node:assert/strict";
import { randomUUID } from "node:crypto";
import { readFileSync, readdirSync } from "node:fs";
import { spawnSync } from "node:child_process";
import { Client } from "pg";
import express from "express";
import swaggerUi from "swagger-ui-express";

const port = Number(process.env.YALLA_TEST_PG_PORT);
assert(Number.isInteger(port) && port > 1024 && port <= 65535, "Set YALLA_TEST_PG_PORT for a disposable local PostgreSQL cluster");
const name = "yalla_test_reviews_" + randomUUID().replaceAll("-", "");
const baseDb = `postgresql://postgres@127.0.0.1:${port}`;
const admin = new Client({ connectionString: baseDb + "/postgres?sslmode=disable" });
const url = baseDb + "/" + name + "?sslmode=disable";
const db = new Client({ connectionString: url });
process.env.DATABASE_URL = url;
process.env.DIRECT_URL = url;
process.env.NODE_ENV = "test";
process.env.DEPLOYMENT_ENV = "staging";
process.env.EXPECTED_DATABASE_HOST = "127.0.0.1";
process.env.EXPECTED_DATABASE_NAME = name;
process.env.PLACE_REVIEW_MODERATOR_UIDS = "fixture-moderator";
process.env.PLACES_CURATOR_UIDS = "fixture-author";
process.env.PLACE_RATING_PRIOR_WEIGHT = "20";

let server: ReturnType<typeof express.application.listen> | undefined;
let closePrisma: (() => Promise<void>) | undefined;
let created = false;
try {
  await admin.connect();
  const target = await admin.query("SELECT inet_server_addr()::text AS address, current_setting('neon.project_id', true) AS neon");
  assert.equal(target.rows[0].address, "127.0.0.1/32");
  assert.equal(target.rows[0].neon, null);
  await admin.query(`CREATE DATABASE "${name}"`);
  created = true;
  await db.connect();
  for (const migration of readdirSync("prisma/migrations").filter((name) => /^\d/.test(name)).sort()) {
    await db.query(readFileSync(`prisma/migrations/${migration}/migration.sql`, "utf8"));
  }

  const { prisma } = await import("../src/config/database.js");
  closePrisma = () => prisma.$disconnect();
  const { createPlaceReviewRoutes } = await import("../src/routes/places/place.review.routes.js");
  const { default: placesRoutes } = await import("../src/routes/places/index.js");
  const { default: profileRoutes } = await import("../src/routes/users/user.profile.routes.js");
  const { default: votingRoutes } = await import("../src/routes/outings/outing.voting.routes.js");
  const { OutingController } = await import("../src/controllers/outings/outing.controller.js");
  const { createAuthMiddleware } = await import("../src/middleware/auth.middleware.js");
  const { errorMiddleware } = await import("../src/middleware/error.middleware.js");
  const { UnauthorizedError } = await import("../src/utils/errors.js");
  const { swaggerSpec } = await import("../src/config/swagger.js");
  const { swaggerCoverage } = await import("../src/app.js");
  assert.deepEqual(swaggerCoverage.undocumented.filter((path) => /rating|review/.test(path)), []);
  assert.deepEqual(swaggerCoverage.unregistered.filter((path) => /rating|review/.test(path)), []);

  const author = "fixture-author", viewer = "fixture-viewer", moderator = "fixture-moderator";
  const users = [author, viewer, moderator, ...Array.from({ length: 8 }, (_, i) => `fixture-reviewer-${i}`)];
  const branch = randomUUID(), sibling = randomUUID(), brand = randomUUID();
  for (const [i, user] of users.entries()) {
    await db.query("INSERT INTO users(id,name,phone) VALUES ($1,$1,$2)", [user, `+155511100${String(i).padStart(2, "0")}`]);
  }
  await db.query("INSERT INTO place_brands(id,name,normalized_name,identity_key) VALUES ($1,'Fixture CafÃ©','fixture cafe','fixture-cafe')", [brand]);
  await db.query(`INSERT INTO places(id,name,brand_id,source,source_type,source_id,latitude,longitude)
    VALUES ($1,'Fixture branch A',$3,'osm','node','901',30,31.2), ($2,'Fixture branch B',$3,'osm','node','902',30,31.21)`, [branch, sibling, brand]);

  const auth = createAuthMiddleware(async (token) => {
    if (!users.includes(token)) throw new UnauthorizedError();
    return { uid: token };
  });
  const app = express();
  app.use(express.json());
  app.get("/api-docs/openapi.json", (_req, res) => res.json(swaggerSpec));
  app.use("/api-docs", swaggerUi.serve, swaggerUi.setup(swaggerSpec));
  app.use("/api/places", createPlaceReviewRoutes(auth));
  app.get("/api/places/saved", auth, new OutingController().getSavedPlaces);
  app.use(placesRoutes);
  app.use("/api/outings", auth, votingRoutes);
  app.use("/api/users", auth, profileRoutes);
  app.use(errorMiddleware);
  server = app.listen(0, "127.0.0.1");
  await new Promise<void>((resolve) => server!.once("listening", resolve));
  const address = server.address();
  assert(address && typeof address !== "string");
  const base = `http://127.0.0.1:${address.port}`;
  assert.equal((await fetch(base + "/api-docs/")).status, 200);
  const spec = await (await fetch(base + "/api-docs/openapi.json")).json() as {
    paths: Record<string, Record<string, { operationId: string; responses: Record<string, unknown> }>>;
  };
  const operations = new Map(Object.entries(spec.paths).flatMap(([path, methods]) =>
    Object.entries(methods).map(([method, operation]) => [operation.operationId, { method, path, operation }] as const)));
  type Call = { uid?: string; params?: Record<string, string>; body?: unknown; query?: Record<string, string>; status?: number };
  const requestEnvelope = async (operation: string, { uid, params = {}, body, query, status = 200 }: Call = {}) => {
    const op = operations.get(operation);
    assert(op, `Unknown Swagger operation ${operation}`);
    assert(op.operation.responses[status], `Undocumented HTTP status for ${operation}: ${status}`);
    const path = op.path.replace(/{(\w+)}/g, (_match, key: string) => encodeURIComponent(params[key] ?? branch));
    const endpoint = new URL(path, base);
    for (const [key, value] of Object.entries(query ?? {})) endpoint.searchParams.set(key, value);
    const result = await fetch(endpoint, {
      method: op.method.toUpperCase(),
      headers: { ...(uid && { authorization: `Bearer ${uid}` }), ...(body !== undefined && { "content-type": "application/json" }) },
      ...(body !== undefined && { body: JSON.stringify(body) }),
    });
    const raw = await result.text();
    assert(raw, `Empty response for ${operation}: HTTP ${result.status}`);
    const json = JSON.parse(raw) as {
      success?: boolean;
      data: any;
      features?: { id: string }[];
      pagination?: { has_more: boolean; next_cursor: string | null; rating_ranking_available?: boolean };
    };
    assert.equal(result.status, status, `${operation}: ${JSON.stringify(json)}`);
    if (operation === "getPlacesGeoJson" && status === 200) assert(Array.isArray(json.features));
    else assert.equal(json.success, status < 400);
    return { ...json, cacheControl: result.headers.get("cache-control") };
  };
  const request = async (operation: string, options?: Call) => (await requestEnvelope(operation, options)).data;
  const getStats = (placeId = branch) => request("getPlaceRatingStatistics", { params: { placeId } });
  const write = (uid: string, rating: number, reviewText?: string, placeId = branch) =>
    request("submitPlaceRating", { uid, body: { rating, reviewText }, params: { placeId } });
  const pass = (message: string) => console.log("PASS " + message);

  {
    const { BayesianRatingService } = await import("../src/services/places/bayesian-rating.service.js");
    const { Prisma } = await import("@prisma/client");
    for (const invalid of ["0", "-1", "1.5", "Infinity", "foo", "9007199254740992"]) {
      assert.throws(() => BayesianRatingService.configuredPriorWeight(invalid), /positive safe integer/);
    }
    assert.equal(BayesianRatingService.configuredPriorWeight(""), 20);
    const [a, b, twin, oneFour, twoFours, below, unrated, low] = Array.from({ length: 8 }, (_, index) =>
      `00000000-0000-4000-8000-${String(index + 1).padStart(12, "0")}`) as
      [string, string, string, string, string, string, string, string];
    await db.query(`INSERT INTO places(id,name,latitude,longitude)
      SELECT id, CASE WHEN position = 8 THEN 'Global prior fixture' ELSE 'Bayesian fixture ' || position END, 30, 31.2
      FROM unnest($1::uuid[]) WITH ORDINALITY AS p(id, position)`, [[a, b, twin, oneFour, twoFours, below, unrated, low]]);
    await db.query("UPDATE places SET brand_id = $1 WHERE id = ANY($2::uuid[])", [brand, [a, b, twin]]);
    const ranked = (query: Record<string, string> = {}, status = 200) => requestEnvelope("listPlaces", {
      query: { sort: "top_rated", search: "Bayesian fixture", compact: "true", ...query }, status,
    });
    const ids = (data: { id: string }[]) => data.map(({ id }) => id);
    const empty = await ranked();
    assert.equal(empty.pagination?.rating_ranking_available, false);
    assert.deepEqual(ids(empty.data), [a, b, twin, oneFour, twoFours, below, unrated]);
    assert(empty.data.every((place: any) =>
      place.rating_statistics.averageRating === null && place.rating_statistics.ratingCount === 0));
    assert.deepEqual((await ranked({ includeUnrated: "false" })).data, []);
    assert.equal((await ranked({ search: "Missing fixture" })).pagination?.rating_ranking_available, false);
    pass("empty global data, unrated fallback and no matches through Swagger");

    await db.query(`INSERT INTO users(id,name,phone)
      SELECT 'bayes-' || n, 'Bayesian fixture reviewer', '+1555222' || lpad(n::text, 4, '0')
      FROM generate_series(1,500) AS s(n)`);
    await db.query(`INSERT INTO place_reviews(place_id,user_id,rating)
      SELECT $1::uuid, $7::text, 5 UNION ALL SELECT $2, $7, 5
      UNION ALL SELECT $3, 'bayes-' || n, CASE WHEN n <= 400 THEN 5 ELSE 4 END FROM generate_series(1,500) s(n)
      UNION ALL SELECT $4, 'bayes-' || n, 3 FROM generate_series(1,451) s(n)
      UNION ALL SELECT $5, 'bayes-' || n, CASE WHEN n <= 49 THEN 5 ELSE 4 END FROM generate_series(1,100) s(n)
      UNION ALL SELECT $6, $7, 4 UNION ALL SELECT $8, 'bayes-' || n, 4 FROM generate_series(1,2) s(n)`,
      [a, twin, b, low, below, oneFour, author, twoFours]);
    const service = new BayesianRatingService();
    const scores = await prisma.$queryRaw<{ id: string; score: unknown; global_sum: bigint; global_count: bigint }[]>`
      SELECT r.place_id AS id, g.rating_sum AS global_sum, g.rating_count AS global_count,
        ${service.scoreSql(Prisma.sql`r.rating_sum`, Prisma.sql`r.rating_count`,
          Prisma.sql`g.rating_sum`, Prisma.sql`g.rating_count`)} AS score
      FROM place_rating_statistics r CROSS JOIN (${service.globalStatisticsSql()}) g
      WHERE r.place_id IN (${a}::uuid, ${b}::uuid, ${low}::uuid)`;
    const expected = new Map([[a, 4.047619047619], [b, 4.769230769231], [low, 3 + 20 / 471]]);
    for (const { id, score, global_sum, global_count } of scores) {
      assert.equal(global_sum, 4n * global_count);
      assert(Math.abs(Number(score) - expected.get(id)!) < 1e-10);
    }
    assert.equal(scores.length, expected.size);
    const full = await ranked();
    assert.equal(full.cacheControl, "no-store");
    assert.equal(full.pagination?.rating_ranking_available, true);
    assert.deepEqual(ids(full.data), [b, below, a, twin, twoFours, oneFour, unrated]);
    assert.equal(full.data[0].rating_statistics.averageRating, 4.8);
    assert.equal(full.data[0].rating_statistics.ratingCount, 500);
    assert.equal(full.data[1].rating_statistics.averageRating, 4.49);
    assert.equal(full.data.at(-1).rating_statistics.averageRating, null);
    assert(full.data.every((place: any) => !("cursor_rating_score" in place) && !("ranking_score" in place)));
    assert.deepEqual(ids((await ranked({ minRating: "4.5", includeUnrated: "true" })).data), [b, a, twin]);
    assert.deepEqual(ids((await ranked({ minRating: "4" })).data), ids(full.data).slice(0, -1));
    assert.deepEqual(ids((await ranked({ search: "Global prior fixture", minRating: "3" })).data), [low]);
    assert.deepEqual((await ranked({ search: "Global prior fixture", minRating: "4" })).data, []);
    assert.equal((await ranked({ search: "Missing fixture" })).pagination?.rating_ranking_available, true);
    await ranked({ minRating: "5.1" }, 400);
    await ranked({ includeUnrated: "yes" }, 400);
    pass("C = 4 and m = 20, small/large samples, low ratings, unrounded filters and actual rating display");

    const paged: string[] = [];
    let cursor: string | null | undefined;
    do {
      const page = await ranked({ limit: "1", ...(cursor && { cursor }) });
      paged.push(...ids(page.data));
      cursor = page.pagination?.next_cursor;
    } while (cursor);
    assert.deepEqual(paged, ids(full.data));
    assert.deepEqual(ids((await ranked({ limit: "2", offset: "2" })).data), [a, twin]);
    const firstCursor = (await ranked({ limit: "1" })).pagination!.next_cursor!;
    await ranked({ cursor: firstCursor, minRating: "3" }, 400);
    await ranked({ cursor: "invalid" }, 400);
    const nearby = await requestEnvelope("listNearbyPlaces", {
      query: { lat: "30", lng: "31.2", sort: "top_rated", minRating: "4.5" },
    });
    assert.deepEqual(ids(nearby.data), [b, a, twin]);
    assert.equal(nearby.pagination?.rating_ranking_available, true);
    const branches = await request("listPlaceBrandBranches", {
      params: { id: brand }, query: { sort: "top_rated", minRating: "4.5" },
    });
    assert.deepEqual(ids(branches), [b, a, twin]);
    const geo = await requestEnvelope("getPlacesGeoJson", {
      query: { bbox: "31.1,29.9,31.3,30.1", sort: "top_rated", minRating: "4.5" },
    });
    assert.deepEqual(ids(geo.features!), [b, a, twin]);
    pass("deterministic ties, cursor/offset pagination and consistent ordering across catalog reads");

    process.env.PLACE_RATING_PRIOR_WEIGHT = "1";
    await ranked({ cursor: firstCursor }, 409);
    assert.deepEqual(ids((await ranked({ limit: "3" })).data), [b, a, twin]);
    process.env.PLACE_RATING_PRIOR_WEIGHT = "20";
    await db.query(`UPDATE place_reviews SET rating = CASE place_id WHEN $1::uuid THEN 4 ELSE 5 END
      WHERE place_id IN ($1::uuid, $2::uuid) AND user_id = $3`, [a, oneFour, author]);
    await ranked({ cursor: firstCursor }, 409);
    await db.query(`UPDATE place_reviews SET rating = CASE place_id WHEN $1::uuid THEN 5 ELSE 4 END
      WHERE place_id IN ($1::uuid, $2::uuid) AND user_id = $3`, [a, oneFour, author]);
    await db.query("UPDATE place_reviews SET rating = 2 WHERE place_id = $1 AND user_id = 'bayes-1'", [low]);
    await ranked({ cursor: firstCursor }, 409);
    const currentCursor = async () => (await ranked({ limit: "1" })).pagination!.next_cursor!;
    let stale = await currentCursor();
    const updated = await request("updatePlaceRating", { uid: author, params: { placeId: a }, body: { rating: 1 } });
    await ranked({ cursor: stale }, 409);
    assert(ids((await ranked()).data).indexOf(a) > ids(full.data).indexOf(a));
    stale = await currentCursor();
    const moderation = { uid: moderator, params: { placeId: a, reviewId: updated.review.id } };
    await request("moderatePlaceReview", { ...moderation, body: { moderationStatus: "hidden" } });
    await ranked({ cursor: stale }, 409);
    assert(!(await ranked({ includeUnrated: "false" })).data.some((place: any) => place.id === a));
    const hiddenCursor = await currentCursor();
    await request("updatePlaceRating", { uid: author, params: { placeId: a }, body: { rating: 5 } });
    await ranked({ cursor: hiddenCursor });
    await request("moderatePlaceReview", { ...moderation, body: { moderationStatus: "visible" } });
    await ranked({ cursor: hiddenCursor }, 409);
    stale = await currentCursor();
    await request("deletePlaceRating", { uid: author, params: { placeId: a } });
    await ranked({ cursor: stale }, 409);
    assert.equal((await ranked()).data.find((place: any) => place.id === a).rating_statistics.ratingCount, 0);
    await db.query("DELETE FROM place_reviews WHERE place_id = ANY($1::uuid[])", [[a, b, twin, oneFour, twoFours, below, unrated, low]]);
    assert.equal((await ranked()).pagination?.rating_ranking_available, false);
    await db.query("DELETE FROM places WHERE id = ANY($1::uuid[])", [[a, b, twin, oneFour, twoFours, below, unrated, low]]);
    pass("prior changes, global changes outside the search, updates, hidden edits, moderation, and deletions invalidate ranked cursors");
  }

  assert.equal((await getStats()).averageRating, null);
  assert.equal((await request("listPlaceRecommendations")).find((p: any) => p.id === branch).rating_statistics.ratingCount, 0);
  await request("getPlaceReviews", { status: 401 });
  await request("submitPlaceRating", { body: { rating: 5 }, status: 401 });
  for (const rating of [0, 6, 3.2, "5"]) {
    await request("submitPlaceRating", { uid: author, body: { rating }, status: 400 });
  }
  await request("submitPlaceRating", { uid: viewer, body: { rating: 5, userId: author }, status: 400 });
  await request("submitPlaceRating", { uid: viewer, body: { rating: 5, reviewText: "https://a.test https://b.test" }, status: 400 });
  await request("updatePlaceRating", { uid: viewer, body: { rating: 4 }, status: 404 });
  await assert.rejects(db.query("INSERT INTO place_reviews(place_id,user_id,rating) VALUES ($1,$2,9)", [branch, author]), { code: "23514" });
  pass("anonymous access, rating boundaries, spam and owner-only patch");

  const first = await write(author, 5);
  assert.equal(first.review.reviewText, null);
  assert.equal(first.statistics.writtenReviewCount, 0);
  assert.equal((await request("getPlaceReviews", { uid: viewer })).items.length, 0);
  const after = await write(author, 4, "Fixture review");
  const reviewId = after.review.id;
  assert.equal(reviewId, first.review.id);
  assert.equal(after.statistics.averageRating, 4);
  assert.equal(after.statistics.ratingCount, 1);
  assert.equal((await request("listPlaceRecommendations")).find((p: any) => p.id === branch).rating_statistics.averageRating, 4);
  await write(author, 2, undefined, sibling);
  assert.equal((await getStats(sibling)).averageRating, 2);
  assert.equal((await getStats()).averageRating, 4);
  pass("rating-only, repeat PUT, recommendation cache freshness and branch independence");

  const outing = randomUUID();
  await db.query("INSERT INTO saved_places(place_id,user_id) VALUES ($1,$2)", [branch, viewer]);
  await db.query(`INSERT INTO outings(id,title,created_by,type,occasion,status,scheduled_at,vote_ends_at)
    VALUES ($1,'Fixture outing',$2,'special_event','other','voting',now()+interval '2 days',now()+interval '1 day')`, [outing, moderator]);
  await db.query(`INSERT INTO outing_vote_options(outing_id,place_id,label,sort_order)
    VALUES ($1,$2,'Catalog branch',0), ($1,NULL,'Manual pin',1)`, [outing, branch]);
  const placeData = await request("listPlaces");
  assert.equal(placeData.find((place: any) => place.id === branch).rating_statistics.ratingCount, 1);
  const saved = await request("listSavedPlaces", { uid: viewer });
  assert.equal(saved[0].places.rating_statistics.ratingCount, 1);
  const voting = await request("getVotingState", { uid: moderator, params: { id: outing } });
  assert.deepEqual(voting.options[0].rating_statistics, after.statistics);
  assert(!("rating_statistics" in voting.options[1]));
  pass("catalog, saved and voting cards receive real branch statistics");

  const group = users.slice(3, 9);
  const writes = await Promise.all(group.map((uid, i) => write(uid, (i % 5) + 1, "Concurrent fixture review")));
  const concurrent = await Promise.all([write(author, 5, "Updated fixture"), write(author, 4, "Updated fixture")]);
  assert(concurrent.every((entry) => entry.review.id === reviewId));
  const own = await request("getMyPlaceRating", { uid: author });
  const stats = await getStats();
  assert.equal(stats.ratingCount, 7);
  assert.equal(stats.writtenReviewCount, 7);
  assert.equal(stats.averageRating, (own.rating + 16) / 7);
  assert.equal(writes.length, 6);
  pass("concurrent first writes and same-owner upserts preserve sums and distribution");

  const page = await request("getPlaceReviews", { uid: viewer, query: { limit: "2" } });
  assert.equal(page.items.length, 2);
  assert(page.nextCursor);
  assert.deepEqual(Object.keys(page.items[0].reviewer), ["name"]);
  assert(!("moderationStatus" in page.items[0]));
  await request("getPlaceReviews", { uid: viewer, query: { cursor: "invalid" }, status: 400 });
  const deletedAnchor = page.items[1].id;
  const anchor = [after, ...writes].find((entry) => entry.review.id === deletedAnchor);
  assert(anchor);
  const anchorOwner = anchor.review.reviewer.name;
  if (anchorOwner !== author) {
    await request("deletePlaceRating", { uid: anchorOwner });
  }
  const next = await request("getPlaceReviews", { uid: viewer, query: { cursor: page.nextCursor, limit: "10" } });
  assert.equal(next.items.length, 5);
  assert(next.items.every((item: any) => !page.items.some((first: any) => first.id === item.id)));
  pass("stable cursor after removing a page anchor, with minimal public reviewer profile");

  const params = { placeId: branch, reviewId };
  await request("reportPlaceReview", { uid: author, params, body: { reason: "spam" }, status: 403 });
  await request("reportPlaceReview", { uid: viewer, params: { ...params, placeId: sibling }, body: { reason: "spam" }, status: 404 });
  const report = await request("reportPlaceReview", { uid: viewer, params, body: { reason: "spam" } });
  assert.deepEqual(await request("reportPlaceReview", { uid: viewer, params, body: { reason: "other" } }), report);
  await request("listPlaceReviewReports", { uid: author, status: 403 });
  let queue = await request("listPlaceReviewReports", { uid: moderator });
  assert.equal(queue.items[0].id, report.id);
  const beforeModeration = await getStats();
  await request("moderatePlaceReview", { uid: viewer, params, body: { moderationStatus: "hidden" }, status: 403 });
  const hidden = await request("moderatePlaceReview", { uid: moderator, params, body: { moderationStatus: "hidden" } });
  assert.equal(hidden.statistics.ratingCount, beforeModeration.ratingCount - 1);
  assert.equal(hidden.statistics.writtenReviewCount, beforeModeration.writtenReviewCount - 1);
  assert.equal((await write(author, 1, "Hidden edit")).review.moderationStatus, "hidden");
  assert.equal((await getStats()).ratingCount, hidden.statistics.ratingCount);
  assert(!(await request("getPlaceReviews", { uid: viewer })).items.some((item: any) => item.id === reviewId));
  queue = await request("listPlaceReviewReports", { uid: moderator });
  assert.equal(queue.items.length, 0);
  const restored = await request("moderatePlaceReview", { uid: moderator, params, body: { moderationStatus: "visible" } });
  assert.equal(restored.statistics.distribution["1"], hidden.statistics.distribution["1"] + 1);
  const dismissed = await request("reportPlaceReview", { uid: users[10], params, body: { reason: "off_topic" } });
  await request("dismissPlaceReviewReport", { uid: viewer, params: { id: dismissed.id }, status: 403 });
  assert.equal((await request("dismissPlaceReviewReport", { uid: moderator, params: { id: dismissed.id } })).status, "dismissed");
  pass("report deduplication, moderation privileges, hidden edits, restoration and report dismissal");

  const blocked = await request("blockPlaceReviewAuthor", { uid: viewer, params });
  await request("removePlaceReviewBlock", { uid: moderator, params: { id: blocked.id } });
  assert.equal((await request("listPlaceReviewBlocks", { uid: viewer })).items[0].id, blocked.id);
  assert(!(await request("getPlaceReviews", { uid: viewer })).items.some((item: any) => item.id === reviewId));
  assert((await request("getPlaceReviews", { uid: moderator })).items.some((item: any) => item.id === reviewId));
  assert.deepEqual(await getStats(), restored.statistics);
  await request("removePlaceReviewBlock", { uid: viewer, params: { id: blocked.id } });
  assert((await request("getPlaceReviews", { uid: viewer })).items.some((item: any) => item.id === reviewId));
  pass("account-only reviewer blocking and unblocking");

  const { commitBatch } = await import("../src/services/places/import-store.js");
  const run = await prisma.place_sync_runs.create({ data: { status: "running", source: "osm" } });
  await prisma.$transaction((tx) => commitBatch(tx, {
    writes: [{
      id: branch, existed: true, source_id: "901", source_type: "node", source: "osm",
      name: "Fixture branch refreshed", name_ar: null, name_en: null, description: "",
      category_id: null, latitude: 30, longitude: 31.2, address: "", city: "Cairo",
      district: "", area: "", phone: null, website: null, opening_hours: null,
      source_region: "EG-C", source_tags: {}, status: "active", vibe: "food",
      raw: { tags: {} }, inferred: [], line: 1,
    }],
    histories: [], reviews: [], aliases: [], prior: [],
  } as unknown as Parameters<typeof commitBatch>[1], "osm", "fixture-release", run.id));
  assert.equal((await request("getPlace", { params: { id: branch } })).rating_statistics.averageRating,
    restored.statistics.averageRating);
  assert.equal((await request("getMyPlaceRating", { uid: author })).id, reviewId);
  await assert.rejects(db.query("DELETE FROM places WHERE id = $1", [branch]), { constraint: "place_reviews_place_id_fkey" });
  // Exercise the same archival use case as the curator route; Firebase stays isolated.
  const { DeletePlaceUseCase } = await import("../src/usecases/places/delete-place.usecase.js");
  await new DeletePlaceUseCase().execute(sibling);
  assert.equal((await getStats(sibling)).ratingCount, 1);
  await request("submitPlaceRating", { uid: viewer, params: { placeId: sibling }, body: { rating: 3 }, status: 409 });
  pass("real import refresh and catalog archival retain reviews and branch IDs");

  const accountDelete = operations.get("deleteCuser") ?? [...operations.values()].find((entry) => entry.path === "/api/users/cuser" && entry.method === "delete");
  assert(accountDelete);
  await request(accountDelete.operation.operationId, { uid: author, status: 202 });
  assert.equal((await getStats()).ratingCount, restored.statistics.ratingCount - 1);
  assert.equal((await getStats(sibling)).ratingCount, 0);
  assert.equal(await prisma.place_reviews.count({ where: { user_id: author } }), 0);
  assert.equal(await prisma.place_review_reports.count({ where: { review_id: reviewId } }), 0);
  const oldCount = (await getStats()).ratingCount;
  assert.equal((await request("deletePlaceRating", { uid: group.find((uid) => uid !== anchorOwner) })).statistics.ratingCount, oldCount - 1);
  pass("owner deletion and coordinated account deletion update aggregates and cascade reports");

  const reconcile = (...args: string[]) => spawnSync(process.execPath,
    ["node_modules/tsx/dist/cli.mjs", "scripts/reconcile-place-ratings.ts", ...args], { encoding: "utf8" });
  const baseline = await getStats();
  assert.equal(reconcile().status, 0);
  await db.query("DELETE FROM place_rating_statistics WHERE place_id = $1", [branch]);
  assert.equal(reconcile().status, 1);
  const repair = reconcile("--repair");
  assert.equal(repair.status, 0, repair.stderr);
  assert.equal(reconcile().status, 0);
  assert.equal((await getStats()).averageRating, baseline.averageRating);
  assert.deepEqual((await getStats()).distribution, baseline.distribution);
  const changes = await request("listPlaceCatalogChanges");
  assert.equal(changes.changes.find((change: any) => change.id === branch).record.rating_statistics.ratingCount, baseline.ratingCount);
  pass("aggregate drift detection, repair and public cache change feed");

  const spammer = users[9]!;
  for (let i = 0; i < 30; i++) await write(spammer, 3);
  await request("submitPlaceRating", { uid: spammer, body: { rating: 3 }, status: 429 });
  pass("per-account write rate limit");
} finally {
  if (server) await new Promise<void>((resolve, reject) => server!.close((error) => error ? reject(error) : resolve()));
  await closePrisma?.();
  await db.end();
  if (created) await admin.query(`DROP DATABASE "${name}" WITH (FORCE)`);
  await admin.end();
}
