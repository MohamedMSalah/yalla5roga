import assert from "node:assert/strict";
import test from "node:test";
import { configuredGeocodingProvider, geocodingRequest } from "../src/services/places/geocoding.js";

test("geocoding is opt-in and never uses public Nominatim", () => {
  assert.equal(configuredGeocodingProvider({}), undefined);
  assert.equal(configuredGeocodingProvider({
    GEOCODING_PROVIDER: "pelias",
    GEOCODING_BASE_URL: "https://nominatim.openstreetmap.org",
    GEOCODING_ATTRIBUTION: "Example",
  }), undefined);
  assert.equal(geocodingRequest.safeParse({
    kind: "reverse", latitude: 0, longitude: 0, language: "ar",
  }).success, true);
  assert.equal(geocodingRequest.safeParse({
    kind: "reverse", latitude: 91, longitude: 0, language: "ar",
  }).success, false);
});

test("Pelias autocomplete sends Arabic language and maps GeoJSON coordinates", async (context) => {
  context.mock.method(globalThis, "fetch", async (input: URL) => {
    assert.equal(input.pathname, "/v1/autocomplete");
    assert.equal(input.searchParams.get("lang"), "ar");
    assert.equal(input.searchParams.get("text"), "القاهرة");
    return Response.json({ features: [{
      geometry: { type: "Point", coordinates: [31.23, 30.04] },
      properties: { gid: "osm:venue:1", name: "القاهرة", locality: "القاهرة" },
    }] });
  });
  const provider = configuredGeocodingProvider({
    GEOCODING_PROVIDER: "pelias",
    GEOCODING_BASE_URL: "https://geo.example.test",
    GEOCODING_ATTRIBUTION: "Example",
  });
  assert.ok(provider);
  assert.equal(provider.cacheSeconds, 0);
  assert.deepEqual(await provider.lookup({
    kind: "search", query: "القاهرة", language: "ar",
  }, new AbortController().signal), [{
    id: "osm:venue:1", name: "القاهرة", area: "القاهرة", latitude: 30.04, longitude: 31.23,
  }]);
});
