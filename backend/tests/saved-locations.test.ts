import { isolatedDatabase } from "./support/isolated-database.js";
import assert from "node:assert/strict";
import { randomInt, randomUUID } from "node:crypto";
import { test } from "node:test";
import { deleteApp, initializeApp } from "firebase-admin/app";
import { getAuth } from "firebase-admin/auth";
import { prisma } from "../src/config/database.js";
import { EffectiveTransportationResolver } from "../src/services/users/effective-transportation-resolver.js";
import { responseAssertion, withApi, type OpenApi } from "./support/http-fixture.js";

const { default: app } = await import("../src/app.js");

test("served routing capabilities declare all preferences storable and all calculations unavailable", async () => {
  await withApi(app, async (url) => {
    const spec = await (await fetch(url + "/api-docs/openapi.json")).json() as OpenApi;
    const path = "/api/routing/capabilities";
    const operation = spec.paths[path].get;
    assert.deepEqual(operation.security, []);
    const response = await fetch(url + path);
    assert.equal(response.status, 200);
    const payload = await response.json();
    responseAssertion(spec, operation, 200, "application/json", payload);
    assert.deepEqual(payload.data, ["CAR", "MOTORCYCLE", "METRO", "WALKING"].map((mode) => ({
      mode,
      can_store_preference: true,
      supports_routes: false,
      supports_matrices: false,
      supports_distance: false,
      supports_duration: false,
      supports_alternatives: false,
      supports_isochrones: false,
      supports_departure_time: false,
      unavailability_reason_code: "ROUTING_NOT_CONFIGURED",
    })));
  });
});

test("served Saved Locations operations enforce ownership and maintain a single default", {
  skip: !isolatedDatabase, timeout: 30_000,
}, async (t) => {
  const owner = `saved-locations-${randomUUID()}`;
  const other = `saved-locations-${randomUUID()}`;
  const firebase = initializeApp({ projectId: "demo-yalla-saved-locations" });
  t.mock.method(getAuth(firebase), "verifyIdToken", async (token: string) => ({
    uid: token === "owner" || token === "owner-second-device" ? owner : other,
    firebase: { sign_in_provider: "custom" },
  }));
  const places: string[] = [];
  try {
    await prisma.users.createMany({ data: [
      { id: owner, name: "Fixture owner", phone: `+2010${randomInt(10000000, 99999999)}` },
      { id: other, name: "Fixture other", phone: `+2011${randomInt(10000000, 99999999)}` },
    ] });
    const place = await prisma.places.create({
      data: { name: "Fixture library", area: "Fixture district", latitude: 30, longitude: 31 },
      select: { id: true },
    });
    places.push(place.id);
    const unlocated = await prisma.places.create({
      data: { name: "Fixture without coordinates" },
      select: { id: true },
    });
    places.push(unlocated.id);

    await withApi(app, async (url) => {
      const served = await fetch(`${url}/api-docs/openapi.json`);
      assert.equal(served.status, 200);
      const spec = await served.json() as OpenApi;
      const list = "/api/users/me/saved-locations";
      const item = `${list}/{id}`;
      const defaultPath = "/api/users/me/default-starting-location";
      const bookmark = "/api/places/{id}/save";
      const account = "/api/users/me/transportation-preferences";
      const resolve = new EffectiveTransportationResolver();
      const call = async (
        method: string, path: string, status: number, token?: string, body?: unknown, id?: string,
      ) => {
        const operation = spec.paths[path]?.[method.toLowerCase()];
        assert.ok(operation, `Missing operation for ${method} ${path}`);
        const response = await fetch(`${url}${id ? path.replace("{id}", id) : path}`, {
          method,
          headers: {
            ...(token ? { authorization: `Bearer ${token}` } : {}),
            ...(body ? { "content-type": "application/json" } : {}),
          },
          body: body === undefined ? undefined : JSON.stringify(body),
        });
        const payload = await response.json();
        assert.equal(response.status, status, `${method} ${path}: ${JSON.stringify(payload)}`);
        responseAssertion(spec, operation, status, "application/json", payload);
        if (response.ok && path.startsWith("/api/users/me/")) {
          assert.equal(response.headers.get("cache-control"), "private, no-store");
        }
        return payload.data;
      };
      const input = {
        name: "Fixture home", location_type: "home", latitude: 30, longitude: 31,
        address: "Fixture private address", approximate_area: "Fixture district", place_id: place.id,
      };
      assert.equal(await call("GET", list, 401), undefined);
      assert.equal(await call("GET", defaultPath, 200, "owner"), null);
      assert.deepEqual(await call("GET", list, 200, "owner"), []);
      await call("POST", list, 400, "owner", { ...input, latitude: 91 });
      await call("POST", list, 400, "owner", { ...input, location_type: "unsupported" });
      await call("POST", list, 400, "owner", { ...input, user_id: other });
      await call("POST", list, 404, "owner", { ...input, place_id: randomUUID() });

      await call("GET", account, 401);
      await call("PATCH", account, 401, undefined, { default_transportation_mode: "CAR" });
      assert.deepEqual(await call("GET", account, 200, "owner"), { default_transportation_mode: null });
      assert.deepEqual(await resolve.resolveForOwner(owner), { mode: null, source: "unspecified" });
      await call("PATCH", account, 400, "owner", {});
      await call("PATCH", account, 400, "owner", { default_transportation_mode: "car" });
      await call("PATCH", account, 400, "owner", { default_transportation_mode: "CAR", user_id: other });
      await call("PATCH", account, 200, "owner", { default_transportation_mode: "CAR" });
      assert.deepEqual(await call("GET", account, 200, "owner-second-device"), { default_transportation_mode: "CAR" });
      assert.deepEqual(await call("GET", account, 200, "other"), { default_transportation_mode: null });
      assert.deepEqual(await resolve.resolveForOwner(owner), { mode: "CAR", source: "user_default" });
      await call("POST", list, 400, "owner", { ...input, preferred_transportation_mode: "BICYCLE" });

      const created = await call("POST", list, 201, "owner", input);
      assert.equal(created.address, input.address);
      assert.equal(created.is_default, false);
      assert.ok(!("user_id" in created));
      assert.deepEqual(await call("GET", list, 200, "owner-second-device"), [created]);
      assert.deepEqual(await call("GET", list, 200, "other"), []);
      assert.deepEqual(await call("GET", item, 200, "owner", undefined, created.id), created);
      await call("GET", item, 404, "other", undefined, created.id);
      await call("GET", "/api/places/{id}", 404, undefined, undefined, created.id);
      const publicPlace = await call("GET", "/api/places/{id}", 200, undefined, undefined, place.id);
      assert.equal(publicPlace.name, "Fixture library");
      assert.ok(!("is_default" in publicPlace));
      await call("PATCH", item, 404, "other", { name: "Other" }, created.id);
      await call("DELETE", item, 404, "other", undefined, created.id);
      await call("PATCH", item, 400, "owner", { latitude: 30.1 }, created.id);
      const personal = { source: "saved_location", referenceId: created.id };
      const savedPlace = { source: "saved_place" as const, referenceId: place.id };
      const selectedLocation = { ...personal, source: "saved_location" as const };
      const second = await call("POST", list, 201, "owner", {
        ...input, name: "Second location", preferred_transportation_mode: "WALKING",
      });
      assert.equal(second.preferred_transportation_mode, "WALKING");
      await call("PATCH", item, 400, "owner", { preferred_transportation_mode: 1 }, created.id);
      await call("PATCH", item, 404, "other", { preferred_transportation_mode: "METRO" }, created.id);
      await call("PATCH", item, 200, "owner", { preferred_transportation_mode: "METRO" }, created.id);
      const secondDeviceLocation = await call("GET", item, 200, "owner-second-device", undefined, created.id);
      assert.equal(secondDeviceLocation.preferred_transportation_mode, "METRO");
      assert.equal((await call("GET", item, 200, "owner", undefined, second.id)).preferred_transportation_mode, "WALKING");
      await call("DELETE", item, 200, "owner", undefined, second.id);
      assert.deepEqual(await call("GET", account, 200, "owner"), { default_transportation_mode: "CAR" });
      assert.deepEqual(await resolve.resolveForOwner(owner, { selectedLocation }), { mode: "METRO", source: "saved_location" });
      assert.deepEqual(await resolve.resolveForOwner(owner, {
        selectedLocation, temporaryOverride: "MOTORCYCLE",
      }), { mode: "MOTORCYCLE", source: "temporary_override" });
      await call("PUT", defaultPath, 404, "other", personal);
      await call("PUT", defaultPath, 404, "owner", savedPlace);
      const selected = await call("PUT", defaultPath, 200, "owner", personal);
      assert.deepEqual(Object.keys(selected).sort(), [
        "approximate_area", "is_default", "latitude", "location_type", "longitude", "name",
        "place_id", "preferred_transportation_mode", "reference_id", "source",
      ]);
      assert.equal(selected.reference_id, created.id);
      assert.equal(selected.location_type, "home");
      assert.equal(selected.preferred_transportation_mode, "METRO");
      assert.equal(selected.place_id, place.id);
      assert.equal(selected.is_default, true);
      assert.equal((await call("GET", list, 200, "owner-second-device"))[0].is_default, true);
      assert.equal(await call("GET", defaultPath, 200, "other"), null);
      await call("PATCH", item, 200, "owner", { name: "Updated home", address: null }, created.id);
      assert.equal((await call("GET", defaultPath, 200, "owner-second-device")).name, "Updated home");

      await call("PATCH", item, 200, "owner", { preferred_transportation_mode: null }, created.id);
      assert.deepEqual(await resolve.resolveForOwner(owner, { selectedLocation, temporaryOverride: null }), {
        mode: "CAR", source: "user_default",
      });
      await call("PATCH", bookmark, 404, "owner", { preferred_transportation_mode: "WALKING" }, place.id);
      await call("POST", bookmark, 201, "owner", undefined, place.id);
      await call("PATCH", bookmark, 401, undefined, { preferred_transportation_mode: "METRO" }, place.id);
      await call("PATCH", bookmark, 404, "other", { preferred_transportation_mode: "METRO" }, place.id);
      await call("PATCH", bookmark, 400, "owner", { preferred_transportation_mode: "TRANSIT" }, place.id);
      await call("PATCH", bookmark, 200, "owner", { preferred_transportation_mode: "METRO" }, place.id);
      assert.deepEqual(await resolve.resolveForOwner(owner, { selectedLocation: savedPlace }), {
        mode: "METRO", source: "saved_location",
      });
      await call("PUT", defaultPath, 200, "owner", savedPlace);
      assert.equal((await call("GET", defaultPath, 200, "owner-second-device")).preferred_transportation_mode, "METRO");
      assert.deepEqual(await call("GET", "/api/places/{id}", 200, undefined, undefined, place.id), publicPlace);
      await call("PATCH", bookmark, 200, "owner", { preferred_transportation_mode: null }, place.id);
      await call("PATCH", account, 200, "owner", { default_transportation_mode: null });
      assert.deepEqual(await resolve.resolveForOwner(owner, { selectedLocation: savedPlace }), {
        mode: null, source: "unspecified",
      });
      await call("POST", bookmark, 201, "owner", undefined, unlocated.id);
      await call("PUT", defaultPath, 400, "owner", { source: "saved_place", referenceId: unlocated.id });
      await call("PUT", defaultPath, 404, "other", savedPlace);
      await call("DELETE", defaultPath, 200, "owner");
      await Promise.all(Array.from({ length: 8 }, (_, i) =>
        call("PUT", defaultPath, 200, "owner", i % 2 === 0 ? personal : savedPlace),
      ));
      assert.equal(await prisma.default_starting_locations.count({ where: { user_id: owner } }), 1);
      await assert.rejects(prisma.default_starting_locations.update({
        where: { user_id: owner },
        data: { saved_location_id: created.id, saved_place_id: place.id },
      }));
      await assert.rejects(prisma.default_starting_locations.create({
        data: { user_id: other, saved_location_id: created.id },
      }));
      await assert.rejects(prisma.saved_locations.update({
        where: { id: created.id },
        data: { longitude: Number.NaN },
      }));

      const bookmarkDefault = await call("PUT", defaultPath, 200, "owner", savedPlace);
      assert.deepEqual(bookmarkDefault, {
        source: "saved_place", reference_id: place.id, place_id: place.id,
        name: "Fixture library", latitude: 30, longitude: 31, approximate_area: "Fixture district",
        location_type: "custom", preferred_transportation_mode: null, is_default: true,
      });
      const ownerLocations = await call("GET", list, 200, "owner");
      assert.equal(ownerLocations.length, 1);
      assert.equal(ownerLocations[0].is_default, false);
      await call("DELETE", bookmark, 200, "owner", undefined, place.id);
      assert.equal(await call("GET", defaultPath, 200, "owner"), null);
      await call("PUT", defaultPath, 200, "owner", personal);
      await call("DELETE", item, 200, "owner", undefined, created.id);
      assert.equal(await call("GET", defaultPath, 200, "owner"), null);
      assert.ok(await prisma.places.findUnique({ where: { id: place.id } }));
      await call("DELETE", defaultPath, 200, "owner");

      const retained = await call("POST", list, 201, "other", input);
      const toDelete = await call("POST", list, 201, "owner", input);
      await call("PUT", defaultPath, 200, "owner", { ...personal, referenceId: toDelete.id });
      await call("DELETE", "/api/users/cuser", 202, "owner");
      assert.equal(await prisma.saved_locations.count({ where: { user_id: owner } }), 0);
      assert.equal(await prisma.default_starting_locations.count({ where: { user_id: owner } }), 0);
      assert.deepEqual(await call("GET", list, 200, "other"), [retained]);
      assert.ok(await prisma.places.findUnique({ where: { id: place.id } }));
    });
  } finally {
    await prisma.users.deleteMany({ where: { id: { in: [owner, other] } } });
    await prisma.places.deleteMany({ where: { id: { in: places } } });
    await deleteApp(firebase);
    await prisma.$disconnect();
  }
});
