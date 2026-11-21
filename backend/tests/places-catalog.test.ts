import { test } from "node:test";
import assert from "node:assert/strict";
import {
  categories,
  vibes,
  classify,
  mappedVibes,
} from "../src/services/places/taxonomy.js";
import {
  normalizeOsm,
  lifecycle,
  overpassQuery,
  validateResponse,
} from "../src/services/places/osm.js";
import { catalogQuerySchema } from "../src/validators/places/catalog.validator.js";
import { CatalogRepository } from "../src/repositories/places/catalog.repository.js";
import { CatalogUseCase } from "../src/usecases/places/catalog.usecase.js";
test("taxonomy has stable unique IDs, distinct cafes/retail coffee and complete bilingual labels", () => {
  assert.equal(new Set(categories.map((c) => c[0])).size, categories.length);
  assert.equal(new Set(vibes.map((v) => v[0])).size, vibes.length);
  assert.ok(categories.length >= 44);
  assert.ok(vibes.length >= 23);
  for (const row of [...categories, ...vibes]) assert.ok(row.every(Boolean));
  assert.equal(classify({ amenity: "cafe" }), "cafes");
  assert.equal(classify({ shop: "coffee" }), "coffee_shops");
});
test("vibes require evidence; no inferred romance, work or affordability", () => {
  assert.deepEqual(mappedVibes("cafes", {}), ["coffee_conversations", "chill_relax", "friends_hangout"]);
  assert.deepEqual(mappedVibes("bowling", {}), [
    "fun_games",
    "friends_hangout",
    "group_activities",
    "entertainment",
  ]);
  assert.deepEqual(mappedVibes("escape_rooms", {}), ["adventure", "fun_games", "group_activities"]);
  assert.ok(mappedVibes("parks", { fee: "no" }).includes("budget_friendly"));
  for (const c of categories)
    for (const vibe of mappedVibes(c[0], {}))
      assert.ok(!["romantic", "budget_friendly", "study_work"].includes(vibe));
});
test("normalization validates names/coordinates and never fabricates source data", () => {
  assert.equal(
    normalizeOsm(
      {
        id: 1,
        type: "node",
        lat: NaN,
        lon: 31,
        tags: { name: "x", amenity: "cafe" },
      },
      "EG-C",
    ),
    null,
  );
  assert.equal(
    normalizeOsm(
      { id: 1, type: "node", lat: 30, lon: 31, tags: { amenity: "cafe" } },
      "EG-C",
    ),
    null,
  );
  const p = normalizeOsm(
    {
      id: 1,
      type: "way",
      center: { lat: 30, lon: 31 },
      tags: {
        "name:ar": "مقهى",
        amenity: "cafe",
        website: "javascript:alert(1)",
      },
    },
    "EG-C",
  )!;
  assert.equal(p.name, "مقهى");
  assert.equal(p.address, null);
  assert.equal(p.opening_hours, null);
  assert.equal(p.phone, null);
  assert.equal(p.source_id, "1");
  assert.equal(p.source_type, "way");
  assert.ok(!p.website?.startsWith("javascript:"));
});
test("lifecycle evidence is conservative and reopening requires current supported tags", () => {
  assert.equal(
    lifecycle({ opening_hours: "closed" }).status,
    "temporarily_closed",
  );
  assert.equal(
    lifecycle({ "disused:amenity": "restaurant" }).status,
    "temporarily_closed",
  );
  assert.equal(
    lifecycle({ "demolished:amenity": "restaurant" }).status,
    "permanently_closed",
  );
  assert.equal(
    normalizeOsm(
      {
        id: 1,
        type: "node",
        lat: 30,
        lon: 31,
        tags: { name: "Reopened", amenity: "restaurant" },
      },
      "EG-C",
    )?.status,
    "active",
  );
});
test("complete response requires boundary evidence, count and fresh OSM timestamp", () => {
  const b = {
    osm3s: { timestamp_osm_base: new Date().toISOString() },
    elements: [
      { type: "count", tags: { areas: "1", total: "1" } },
      { type: "node", id: 1 },
      { type: "count", tags: { total: "1" } },
    ],
  };
  assert.equal(validateResponse(b).length, 1);
  assert.throws(() => validateResponse({ ...b, remark: "runtime timeout" }));
  assert.throws(() =>
    validateResponse({ ...b, elements: b.elements.slice(0, -1) }),
  );
  assert.throws(() =>
    validateResponse({
      ...b,
      osm3s: { timestamp_osm_base: "2020-01-01T00:00:00Z" },
    }),
  );
  assert.match(overpassQuery("EG-GZ", "amenity"), /ISO3166-2/);
  assert.throws(() => overpassQuery("EG-C", "invalid"));
});
test("catalog query supports combined filtering and rejects malformed spatial requests", () => {
  const q = catalogQuerySchema.parse({
    categories: "cafes,cafes,parks",
    vibes: "outdoor_nature,coffee_conversations",
    lat: "30",
    lng: "31",
    sort: "distance",
    radiusKm: "10",
  });
  assert.deepEqual(q.categories, ["cafes", "parks"]);
  assert.equal(q.status, "active");
  for (const input of [
    { lat: "30" },
    { bbox: "31,30,31,32" },
    { bbox: "181,30,-179,32" },
    { bbox: "180,30,-180,32" },
    { bbox: "30,32,31,30" },
    { bbox: ",30,31,32" },
    { limit: "101" },
    { categories: "x' OR true" },
    { sort: "distance" },
  ])
    assert.equal(catalogQuerySchema.safeParse(input).success, false);
});

test("catalog accepts an antimeridian viewport and compact cards together", () => {
  const filters = catalogQuerySchema.parse({ bbox: "175,-10,-175,10", compact: "true" });
  assert.deepEqual(filters.bbox, [175, -10, -175, 10]);
  assert.equal(filters.compact, "true");
});

test("Home recommendation reads share one bounded sample across concurrent limits", async () => {
  let requests = 0;
  class TestCatalog extends CatalogRepository {
    override async recommendations(limit: number) {
      requests++;
      assert.equal(limit, 24);
      return Array.from({length: limit}, (_, id) => ({ id }));
    }
  }
  const catalog = new CatalogUseCase(new TestCatalog());
  const [eight, four] = await Promise.all([catalog.recommendations(8), catalog.recommendations(4)]);
  assert.equal(eight.length, 8);
  assert.deepEqual(four, eight.slice(0, 4));
  assert.deepEqual(await catalog.recommendations(8), eight);
  assert.equal(requests, 1);
});

test("geographic keyset cursor is accepted without changing legacy sort defaults", () => {
  const q = catalogQuerySchema.parse({ bbox: "31,29,32,30", compact: "true", sort: "id" });
  assert.equal(q.sort, "id");
  assert.equal(catalogQuerySchema.parse({}).sort, "updated");
  assert.equal(catalogQuerySchema.safeParse({ ...q, bbox: "31,29,32,30", categories: "", vibes: "", cursor: "cursor", offset: 1 }).success, false);
});
