import assert from "node:assert/strict";
import { randomInt, randomUUID } from "node:crypto";
import { test } from "node:test";
import { deleteApp, initializeApp } from "firebase-admin/app";
import { getAuth } from "firebase-admin/auth";
import { prisma } from "../src/config/database.js";
import { LocationUsageAuthorizationService } from "../src/services/users/location-usage-authorization.service.js";
import { ResolveAuthorizedStartingLocationUseCase } from "../src/usecases/users/location-privacy.usecases.js";
import { responseAssertion, withApi, type OpenApi } from "./support/http-fixture.js";
import { isolatedDatabase } from "./support/isolated-database.js";

const { default: app } = await import("../src/app.js");
const settings = "/api/users/me/location-privacy";
const consent = "/api/users/me/location-consent";
const exclusions = consent + "/excluded-groups";
const exclusion = exclusions + "/{groupId}";
const shared = "/api/groups/{groupId}/members/{userId}/starting-location-area";
const saved = "/api/users/me/saved-locations";
const starting = "/api/users/me/default-starting-location";

test("served Swagger protects all eight location privacy operations", async () => {
  await withApi(app, async (url) => {
    const spec = await (await fetch(url + "/api-docs/openapi.json")).json() as OpenApi;
    const operations = [
      ["GET", settings], ["PATCH", settings], ["PUT", consent], ["DELETE", consent],
      ["GET", exclusions], ["PUT", exclusion], ["DELETE", exclusion], ["GET", shared],
    ];
    for (const [method, path] of operations) {
      const op = spec.paths[path][method.toLowerCase()];
      assert.deepEqual(op.security, [{ bearerAuth: [] }]);
      const actual = path.replace("{groupId}", randomUUID()).replace("{userId}", "member");
      const response = await fetch(url + actual, { method });
      assert.equal(response.status, 401);
      responseAssertion(spec, op, 401, "application/json", await response.json());
    }
  });
});

test("Swagger enforces ownership, current membership and independent location controls", {
  skip: !isolatedDatabase, timeout: 60_000,
}, async (t) => {
  const names = ["owner", "member", "pending", "outsider"] as const;
  type Identity = typeof names[number];
  const ids = Object.fromEntries(names.map((name) => [name, `location-privacy-${randomUUID()}`])) as Record<Identity, string>;
  const pendingPhone = `+2012${randomInt(10000000, 99999999)}`;
  const firebase = initializeApp({ projectId: "demo-yalla-location-privacy" });
  t.mock.method(getAuth(firebase), "verifyIdToken", async (token: Identity) => ({
    uid: ids[token], firebase: { sign_in_provider: "custom" },
  }));
  const groupId = randomUUID();
  const otherGroupId = randomUUID();
  const placeId = randomUUID();
  const point = { latitude: 30.04321, longitude: 31.25432 };
  const authorization = new LocationUsageAuthorizationService();
  const resolveLocation = new ResolveAuthorizedStartingLocationUseCase(authorization);
  try {
    await prisma.users.createMany({
      data: names.map((name, i) => ({
        id: ids[name], name: `Fixture ${name}`,
        phone: name === "pending" ? pendingPhone : `+201${i}${randomInt(10000000, 99999999)}`,
      })),
    });
    await prisma.groups.createMany({
      data: [groupId, otherGroupId].map((id) => ({ id, name: "Fixture group", created_by: ids.owner })),
    });
    await prisma.group_members.createMany({
      data: [
        { group_id: groupId, user_id: ids.owner, role: "owner" },
        { group_id: groupId, user_id: ids.member },
        { group_id: otherGroupId, user_id: ids.owner, role: "owner" },
      ],
    });
    await prisma.group_invitations.create({
      data: {
        group_id: groupId, user_id: ids.pending, invited_by_user_id: ids.owner,
        invited_phone: pendingPhone, expires_at: new Date(Date.now() + 60_000),
      },
    });
    await prisma.places.create({
      data: { id: placeId, name: "Public catalog place", district: "Maadi", ...point },
    });

    await withApi(app, async (url) => {
      const spec = await (await fetch(url + "/api-docs/openapi.json")).json() as OpenApi;
      const call = async (
        method: string, path: string, status: number, caller: Identity,
        body?: unknown, params: Record<string, string> = {},
      ) => {
        const operation = spec.paths[path][method.toLowerCase()];
        const actual = Object.entries({ groupId, userId: ids.member, ...params })
          .reduce((value, [key, replacement]) => value.replace(`{${key}}`, replacement), path);
        const response = await fetch(url + actual, {
          method,
          headers: { authorization: `Bearer ${caller}`, ...(body ? { "content-type": "application/json" } : {}) },
          body: body === undefined ? undefined : JSON.stringify(body),
        });
        const payload = await response.json();
        assert.equal(response.status, status, `${method} ${path}: ${JSON.stringify(payload)}`);
        responseAssertion(spec, operation, status, "application/json", payload);
        if (response.ok && (path.startsWith("/api/users/me/") || path === shared)) {
          assert.equal(response.headers.get("cache-control"), "private, no-store");
        }
        return payload.data;
      };
      const initial = await call("GET", settings, 200, "member");
      assert.equal(initial.location_visibility, "APPROXIMATE");
      assert.equal(initial.automatic_meetup_location_usage_enabled, false);
      assert.equal(initial.location_usage_consent_at, null);
      assert.equal(initial.consent_policy_version, null);
      assert.equal(initial.setup_status, "CONSENT_REQUIRED");
      const grant = { consent_policy_version: initial.required_consent_policy_version };
      await call("PUT", consent, 400, "member", {});
      await call("PUT", consent, 409, "member", { consent_policy_version: "obsolete" });
      await call("PATCH", settings, 400, "owner", { location_visibility: "HIDDEN", user_id: ids.member });
      assert.equal((await call("PUT", consent, 200, "owner", grant)).setup_status, "STARTING_LOCATION_REQUIRED");
      await call("DELETE", consent, 200, "owner");

      assert.deepEqual(await call("GET", shared, 200, "owner"), { status: "UNAVAILABLE", district: null });
      const personal = await call("POST", saved, 201, "member", {
        ...point, name: "Private home", address: "12 Private Street",
        approximate_area: "Private label", location_type: "home", place_id: placeId,
      });
      await call("PUT", starting, 200, "member", { source: "saved_location", referenceId: personal.id });
      const ownPoint = await call("GET", starting, 200, "member");
      assert.equal(ownPoint.latitude, point.latitude);
      assert.equal(ownPoint.longitude, point.longitude);
      assert.equal(ownPoint.name, "Private home");
      assert.equal(await call("GET", starting, 200, "owner"), null);
      await call("GET", saved + "/{id}", 404, "owner", undefined, { id: personal.id });
      assert.deepEqual(await call("GET", shared, 200, "owner"), { status: "APPROXIMATE", district: "Maadi" });
      await call("GET", shared, 403, "pending");
      await call("GET", shared, 403, "outsider");
      await call("GET", shared, 404, "owner", undefined, { userId: ids.pending });
      await call("PUT", exclusion, 403, "pending");
      await call("PUT", exclusion, 403, "member", undefined, { groupId: otherGroupId });

      assert.deepEqual(await resolveLocation.execute(groupId, ids.owner, ids.member), {
        status: "CONSENT_REQUIRED", userId: ids.member,
      });
      await assert.rejects(resolveLocation.execute(groupId, ids.pending, ids.member), { statusCode: 403 });
      assert.deepEqual(await resolveLocation.execute(groupId, ids.owner, ids.pending), {
        status: "MEMBERSHIP_REQUIRED", userId: ids.pending,
      });

      // A forged catalog relationship and an address stored in a district field both fail closed.
      await call("PATCH", saved + "/{id}", 200, "member", { ...point, latitude: 30 }, { id: personal.id });
      assert.deepEqual(await call("GET", shared, 200, "owner"), { status: "UNAVAILABLE", district: null });
      await call("PATCH", saved + "/{id}", 200, "member", point, { id: personal.id });
      await prisma.places.update({ where: { id: placeId }, data: { district: "Private Street" } });
      assert.deepEqual(await call("GET", shared, 200, "owner"), { status: "UNAVAILABLE", district: null });
      await prisma.places.update({ where: { id: placeId }, data: { district: "Maadi" } });

      const hidden = await call("PATCH", settings, 200, "member", { location_visibility: "HIDDEN" });
      assert.equal(hidden.automatic_meetup_location_usage_enabled, false);
      assert.deepEqual(await call("GET", shared, 200, "owner"), { status: "HIDDEN", district: null });
      const enabled = await call("PUT", consent, 200, "member", grant);
      assert.equal(enabled.setup_status, "READY");
      assert.equal(enabled.location_visibility, "HIDDEN");
      assert.equal((await call("PUT", consent, 200, "member", grant)).location_usage_consent_at, enabled.location_usage_consent_at);
      assert.deepEqual(await call("GET", shared, 200, "owner"), { status: "HIDDEN", district: null });

      const started = await resolveLocation.execute(groupId, ids.owner, ids.member);
      assert.equal(started.status, "READY");
      assert.deepEqual(started.points.get(ids.member), point);
      assert.ok(!JSON.stringify(started.authorization).includes("latitude"));
      const canUse = (proof: typeof started.authorization, caller = ids.owner) =>
        authorization.withCurrentAuthorization(proof, caller, async () => "protected result");
      assert.deepEqual(await canUse(started.authorization), { authorized: true, result: "protected result" });
      assert.deepEqual(await canUse(started.authorization, ids.pending), { authorized: false });

      assert.deepEqual(await call("PUT", exclusion, 200, "member"), { group_id: groupId, excluded: true });
      await call("PUT", exclusion, 200, "member");
      assert.deepEqual((await call("GET", exclusions, 200, "member")).map((group: { group_id: string }) => group.group_id), [groupId]);
      assert.deepEqual(await call("GET", exclusions, 200, "owner"), []);
      assert.deepEqual(await resolveLocation.execute(groupId, ids.owner, ids.member), {
        status: "GROUP_EXCLUDED", userId: ids.member,
      });
      assert.deepEqual(await canUse(started.authorization), { authorized: false });
      await call("DELETE", exclusion, 200, "member");
      assert.deepEqual(await canUse(started.authorization), { authorized: false });

      const beforeWithdrawal = await resolveLocation.execute(groupId, ids.owner, ids.member);
      assert.equal(beforeWithdrawal.status, "READY");
      const withdrawn = await call("DELETE", consent, 200, "member");
      assert.equal(withdrawn.setup_status, "CONSENT_REQUIRED");
      assert.equal(withdrawn.location_usage_consent_at, null);
      assert.equal(withdrawn.consent_policy_version, null);
      assert.deepEqual(await authorization.withCurrentAuthorization(beforeWithdrawal.authorization, ids.owner, async () => {
        assert.fail("Withdrawn work must not execute");
      }), { authorized: false });
      await call("PUT", consent, 200, "member", grant);
      assert.deepEqual(await canUse(beforeWithdrawal.authorization), { authorized: false });

      const beforeRemoval = await resolveLocation.execute(groupId, ids.owner, ids.member);
      assert.equal(beforeRemoval.status, "READY");
      await call("DELETE", "/api/groups/{id}/members/{userId}", 200, "owner", undefined, { id: groupId });
      await call("GET", shared, 403, "member", undefined, { userId: ids.owner });
      assert.deepEqual(await canUse(beforeRemoval.authorization, ids.member), { authorized: false });
      assert.deepEqual(await resolveLocation.execute(groupId, ids.owner, ids.member), {
        status: "MEMBERSHIP_REQUIRED", userId: ids.member,
      });
      await prisma.group_members.create({ data: { group_id: groupId, user_id: ids.member } });
      assert.deepEqual(await canUse(beforeRemoval.authorization), { authorized: false });
      assert.equal((await resolveLocation.execute(groupId, ids.owner, ids.member)).status, "READY");

      await call("PUT", exclusion, 200, "member");
      await call("DELETE", "/api/groups/{id}/members/{userId}", 200, "owner", undefined, { id: groupId });
      assert.deepEqual(await call("GET", exclusions, 200, "member"), []);
      await call("DELETE", exclusion, 403, "member");
      await prisma.group_members.create({ data: { group_id: groupId, user_id: ids.member } });
      assert.equal((await resolveLocation.execute(groupId, ids.owner, ids.member)).status, "GROUP_EXCLUDED");
      await call("DELETE", exclusion, 200, "member");
      assert.deepEqual(await canUse(beforeRemoval.authorization), { authorized: false });
    });
    await prisma.user_location_group_exclusions.create({ data: { user_id: ids.member, group_id: groupId } });
    await prisma.users.delete({ where: { id: ids.member } });
    assert.equal(await prisma.user_location_privacy.count({ where: { user_id: ids.member } }), 0);
    assert.equal(await prisma.user_location_group_exclusions.count({ where: { user_id: ids.member } }), 0);
  } finally {
    await prisma.notification_events.deleteMany({ where: { group_id: { in: [groupId, otherGroupId] } } });
    await prisma.groups.deleteMany({ where: { id: { in: [groupId, otherGroupId] } } });
    await prisma.users.deleteMany({ where: { id: { in: Object.values(ids) } } });
    await prisma.places.deleteMany({ where: { id: placeId } });
    await deleteApp(firebase);
  }
});
