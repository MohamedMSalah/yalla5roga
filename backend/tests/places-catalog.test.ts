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
test("taxonomy has stable unique IDs, distinct cafes/retail coffee and complete bilingual labels", () => {
  assert.equal(categories.length, 36);
  assert.equal(vibes.length, 15);
  assert.equal(new Set(categories.map((c) => c[0])).size, 36);
  for (const row of [...categories, ...vibes]) assert.ok(row.every(Boolean));
  assert.equal(classify({ amenity: "cafe" }), "cafes");
  assert.equal(classify({ shop: "coffee" }), "coffee_shops");
});
test("vibes require evidence; no inferred romance, work or affordability", () => {
  assert.deepEqual(mappedVibes("cafes", {}), ["coffee_conversations"]);
  assert.deepEqual(mappedVibes("bowling", {}), [
    "fun_games",
    "friends_hangout",
  ]);
  assert.deepEqual(mappedVibes("escape_rooms", {}), ["fun_games", "adventure"]);
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
    { bbox: "31,30,29,32" },
    { limit: "101" },
    { categories: "x' OR true" },
    { sort: "distance" },
  ])
    assert.equal(catalogQuerySchema.safeParse(input).success, false);
});
