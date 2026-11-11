import assert from "node:assert/strict";
import test from "node:test";
import { arrivalWindowOpen, isAtVenue } from "../src/services/outings/arrival-policy.js";

test("arrivals open at the scheduled instant and close at the event end", () => {
  const start = new Date("2026-11-09T16:00:00Z");
  const end = new Date("2026-11-09T17:00:00Z");
  const outing = { status: "confirmed" as const, scheduled_at: start, ends_at: end };
  assert.equal(arrivalWindowOpen(outing, new Date(start.getTime() - 1)), false);
  assert.equal(arrivalWindowOpen(outing, start), true);
  assert.equal(arrivalWindowOpen(outing, end), false);
  assert.equal(arrivalWindowOpen({ ...outing, status: "voting" }, start), false);
  assert.equal(arrivalWindowOpen({ ...outing, status: "draft" }, start), false);
  assert.equal(arrivalWindowOpen({ ...outing, status: "cancelled" }, start), false);
  assert.equal(arrivalWindowOpen({ ...outing, ends_at: null }, new Date("2026-11-09T22:00:00Z")), false);
});

test("arrival requires a nearby fix with acceptable GPS accuracy", () => {
  const venue = { latitude: 30, longitude: 31 };
  assert.equal(isAtVenue({ ...venue, accuracy: 15 }, 30, 31), true);
  assert.equal(isAtVenue({ ...venue, accuracy: 151 }, 30, 31), false);
  assert.equal(isAtVenue({ latitude: 30.001, longitude: 31, accuracy: 1 }, 30, 31), false);
  assert.equal(isAtVenue({ latitude: 30.00085, longitude: 31, accuracy: 10 }, 30, 31), true);
  assert.equal(isAtVenue({ latitude: 30.0005, longitude: 31, accuracy: 15 }, 30, 31), true);
  assert.equal(isAtVenue({ ...venue, latitude: 30.1, accuracy: 1 }, 30, 31), false);
});
