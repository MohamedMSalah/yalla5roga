import assert from "node:assert/strict";
import test from "node:test";
import { nearbySearchBounds } from "../src/services/places/nearby-search-bounds.js";
import { nearbyPlacesQuerySchema } from "../src/validators/places/place.validator.js";

test("nearby bounds include places near the radius edge", () => {
  const bounds = nearbySearchBounds(30, 31, 5);
  assert.ok(bounds.latitude[1] > 30.04495);
  assert.equal(bounds.longitudes.length, 1);
});

test("nearby bounds span both sides of the date line", () => {
  for (const longitude of [179.99, -179.99]) {
    const bounds = nearbySearchBounds(0, longitude, 5);
    for (const candidate of [179.99, -179.99]) {
      assert.ok(bounds.longitudes.some(([west, east]) => west <= candidate && candidate <= east));
    }
  }
});

test("a radius that reaches a pole does not restrict longitude", () => {
  const bounds = nearbySearchBounds(89.99, 31, 5);
  assert.equal(bounds.latitude[1], 90);
  assert.deepEqual(bounds.longitudes, []);
});

test("nearby search rejects blank and out-of-range coordinates but accepts zero", () => {
  assert.equal(nearbyPlacesQuerySchema.safeParse({ lat: "", lng: " " }).success, false);
  assert.equal(nearbyPlacesQuerySchema.safeParse({ lat: "91", lng: "0" }).success, false);
  assert.deepEqual(nearbyPlacesQuerySchema.parse({ lat: "0", lng: "0" }), { lat: 0, lng: 0 });
});
