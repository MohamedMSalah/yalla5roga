import assert from "node:assert/strict";
import { test } from "node:test";
import { createOutingBodySchema } from "../src/validators/outings/outing.validator.js";

const group = "60b68214-41b5-40fa-93e4-ad9d9210b51a";

test("fixed location supports a snapshot without accepting a device-local place ID", () => {
  const fixed = { title: "Map test", group_id: group, vote_deadline_hours: 3, location_name: "Garden",
    location_latitude: 0, location_longitude: 0, location_category_id: "parks", location_address: "North entrance" };
  const parsed = createOutingBodySchema.parse(fixed);
  assert.equal(parsed.location_category_id, "parks");
  assert.equal(parsed.location_address, "North entrance");
  assert.equal(parsed.location_place_id, undefined);
  assert(!createOutingBodySchema.safeParse({ ...fixed, location_place_id: "private:saved-place" }).success);
});

test("mixed public and custom candidates keep their own location data", () => {
  const body = createOutingBodySchema.parse({
    title: "Map test", group_id: group, vote_deadline_hours: 3, initial_vote_options: [
      { label: "Public", place_id: "90b68214-41b5-40fa-93e4-ad9d9210b51a" },
      { label: "Garden", latitude: 30, longitude: 31, category_id: "parks", address: "North entrance" },
    ],
  });
  assert.equal(body.initial_vote_options?.[1]?.category_id, "parks");
  assert.equal(body.initial_vote_options?.[1]?.address, "North entrance");
  assert.equal(body.initial_vote_options?.[1]?.place_id, undefined);
});
