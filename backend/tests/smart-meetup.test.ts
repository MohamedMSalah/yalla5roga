import assert from "node:assert/strict";
import { randomInt, randomUUID } from "node:crypto";
import { test } from "node:test";
import { deleteApp, initializeApp } from "firebase-admin/app";
import { getAuth } from "firebase-admin/auth";
import app, { swaggerCoverage } from "../src/app.js";
import { prisma } from "../src/config/database.js";
import { locationUsagePolicyVersion } from "../src/types/users/location-privacy.types.js";
import { MeetupSessionRepository } from "../src/repositories/meetups/meetup-session.repository.js";
import { defaultMeetupPreferences } from "../src/types/meetups/meetup-preferences.js";
import { isolatedDatabase } from "./support/isolated-database.js";
import { responseAssertion, withApi, type OpenApi } from "./support/http-fixture.js";

const groupPath = "/api/groups/{groupId}/smart-meetup";
const sessionPath = "/api/smart-meetups/{sessionId}";
const standalonePath = "/api/smart-meetups/standalone";
const participantsPath = sessionPath + "/participants";
const participantPath = participantsPath + "/{participantId}";
const preferencesPath = sessionPath + "/preferences";
const resetPath = preferencesPath + "/reset";
const filterOptionsPath = "/api/smart-meetups/filter-options";
const operations = [
  ["POST", groupPath], ["GET", sessionPath], ["GET", sessionPath + "/readiness"],
  ["POST", sessionPath + "/refresh"], ["PATCH", preferencesPath], ["DELETE", sessionPath],
  ["GET", sessionPath + "/results"], ["POST", sessionPath + "/calculate"],
  ["GET", sessionPath + "/calculations/{calculationId}"],
  ["GET", preferencesPath], ["PUT", preferencesPath], ["POST", resetPath], ["GET", filterOptionsPath],
  ["POST", standalonePath], ["GET", participantsPath], ["POST", participantsPath],
  ["PATCH", participantPath], ["DELETE", participantPath],
];

test("served Swagger documents every authenticated Smart Meetup operation", async () => {
  assert.deepEqual(swaggerCoverage.undocumented, []);
  assert.deepEqual(swaggerCoverage.unregistered, []);
  await withApi(app, async url => {
    const spec = await (await fetch(url + "/api-docs/openapi.json")).json() as OpenApi;
    for (const [method, path] of operations) {
      const operation = spec.paths[path][method.toLowerCase()];
      assert.deepEqual(operation.security, [{ bearerAuth: [] }]);
      const response = await fetch(url + path.replace(/\{\w+\}/g, () => randomUUID()), { method });
      assert.equal(response.status, 401);
      responseAssertion(spec, operation, 401, "application/json", await response.json());
    }
  });
});

test("Swagger verifies Quick Meetup owner scope, temporary inputs and cleanup",
  { skip: !isolatedDatabase, timeout: 60_000 }, async t => {
  const ids = { owner: "quick-" + randomUUID(), other: "quick-" + randomUUID() };
  type Identity = keyof typeof ids;
  const firebase = initializeApp({ projectId: "demo-yalla-quick" });
  t.mock.method(getAuth(firebase), "verifyIdToken", async (token: Identity) => ({
    uid: ids[token], firebase: { sign_in_provider: "custom" },
  }));
  const point = { latitude: 30.04123, longitude: 31.25123 };
  try {
    await prisma.users.createMany({ data: Object.entries(ids).map(([name, id], i) => ({
      id, name, phone: `+201${i}${randomInt(10000000, 99999999)}`, default_transportation_mode: "CAR",
    })) });
    const profilesBefore = await prisma.users.findMany({ where: { id: { in: Object.values(ids) } }, orderBy: { id: "asc" } });
    const identities = { in: Object.values(ids) };
    const relatedCounts = () => Promise.all([
      prisma.users.count({ where: { id: identities } }),
      prisma.groups.count({ where: { created_by: identities } }),
      prisma.group_members.count({ where: { user_id: identities } }),
      prisma.group_invitations.count({ where: { OR: [{ user_id: identities }, { invited_by_user_id: identities }] } }),
    ]);
    const countsBefore = await relatedCounts();
    const saved = await prisma.saved_locations.create({ data: {
      ...point, user_id: ids.owner, name: "Private label", address: "Private address", location_type: "home",
      preferred_transportation_mode: "METRO",
    } });
    await prisma.default_starting_locations.create({ data: { user_id: ids.owner, saved_location_id: saved.id } });

    await withApi(app, async url => {
      const spec = await (await fetch(url + "/api-docs/openapi.json")).json() as OpenApi;
      async function call(method: string, path: string, options: {
        who?: Identity; status?: number; body?: unknown; sessionId?: string; participantId?: string;
      } = {}) {
        const { who = "owner", status = 200, body, sessionId = randomUUID(), participantId = randomUUID() } = options;
        const response = await fetch(url + path.replace("{sessionId}", sessionId).replace("{participantId}", participantId), {
          method, headers: { authorization: "Bearer " + who, ...(body === undefined ? {} : { "content-type": "application/json" }) },
          ...(body === undefined ? {} : { body: JSON.stringify(body) }),
        });
        const payload = await response.json();
        assert.equal(response.status, status, `${method} ${path}: ${JSON.stringify(payload)}`);
        responseAssertion(spec, spec.paths[path][method.toLowerCase()], status, "application/json", payload);
        if (response.ok) {
          assert.equal(response.headers.get("cache-control"), "private, no-store");
          assert.doesNotMatch(JSON.stringify(payload), /user_id|Private label|Private address|input_digest/);
        }
        return payload.data;
      }

      await call("POST", standalonePath, { status: 400, body: { group_id: randomUUID() } });
      const created = await Promise.all(Array.from({ length: 4 }, () => call("POST", standalonePath)));
      const sessionId = created[0].id as string;
      assert.ok(created.every(session => session.id === sessionId && session.input_version === 1));
      assert.equal(created[0].session_type, "STANDALONE");
      assert.equal(created[0].group_id, null);
      assert.equal(created[0].standalone_participants[0].participant_type, "OWNER");
      assert.equal(created[0].standalone_participants[0].latitude, null);
      await prisma.user_location_privacy.create({ data: {
        user_id: ids.owner, location_visibility: "HIDDEN", automatic_meetup_location_usage_enabled: true,
        consent_policy_version: locationUsagePolicyVersion, location_usage_consent_at: new Date(),
      } });
      const ownerReady = await call("POST", sessionPath + "/refresh", { sessionId });
      assert.equal(ownerReady.standalone_participants[0].latitude, point.latitude);
      assert.equal(ownerReady.standalone_participants[0].transportation_mode, "METRO");
      assert.equal(await prisma.meetup_manual_participants.count({ where: { meetup_session_id: sessionId } }), 0);

      const second = await call("POST", standalonePath, { who: "other" });
      assert.notEqual(second.id, sessionId);
      await call("GET", sessionPath, { sessionId, who: "other", status: 404 });
      await call("GET", participantsPath, { sessionId, who: "other", status: 404 });
      const defaults = defaultMeetupPreferences();
      assert.deepEqual(await call("GET", preferencesPath, { sessionId }), defaults);
      await call("GET", preferencesPath, { sessionId, who: "other", status: 404 });
      await call("PUT", preferencesPath, { sessionId, who: "other", status: 404, body: defaults });
      const filterOptions = await call("GET", filterOptionsPath);
      const selectedCategory = filterOptions.categories[0].id;
      const extraPreference = {
        ...defaults, categoryIds: [selectedCategory], budgetLevels: ["MODERATE", "AFFORDABLE"],
        minimumRating: 4.5, maximumTravelDurationSeconds: 2700, travelFairnessMode: "EQUAL_TRAVEL",
        additionalPriorities: ["TOP_RATED", "BUDGET_FRIENDLY", "SHORTEST_DISTANCE"],
        plannedMeetupAt: "2026-11-28T19:00:00+02:00", requireOpenAtMeetupTime: true,
      };
      for (const invalid of [
        { categoryIds: ["absent-category"] }, { categoryIds: [selectedCategory, selectedCategory] },
        { budgetLevels: ["UNKNOWN"] }, { budgetLevels: ["AFFORDABLE", "AFFORDABLE"] },
        { minimumRating: 3.5 }, { maximumTravelDurationSeconds: 45 },
        { travelFairnessMode: "SHORTEST_TOTAL_TIME" }, { additionalPriorities: ["ANYTHING"] },
        { plannedMeetupAt: "2026-11-28T19:00:00" }, { requireOpenAtMeetupTime: 1 }, { weight: 50 },
      ]) {
        await call("PUT", preferencesPath, { sessionId: second.id, who: "other", status: 400,
          body: { ...extraPreference, ...invalid } });
      }
      const stored = await call("PUT", preferencesPath, { sessionId: second.id, who: "other", body: extraPreference });
      assert.equal(stored.input_version, second.input_version + 1);
      assert.equal(stored.calculation_status, "ROUTING_UNAVAILABLE");
      assert.deepEqual(stored.preferences.categoryIds, [selectedCategory]);
      assert.equal(stored.preferences.plannedMeetupAt, "2026-11-28T17:00:00.000Z");
      assert.deepEqual(await call("GET", preferencesPath, { sessionId: second.id, who: "other" }), stored.preferences);
      const reordered = await call("PUT", preferencesPath, { sessionId: second.id, who: "other",
        body: { ...extraPreference, budgetLevels: ["AFFORDABLE", "MODERATE"] } });
      assert.equal(reordered.input_version, stored.input_version);
      assert.deepEqual(await call("GET", preferencesPath, { sessionId }), defaults);
      const reset = await call("POST", resetPath, { sessionId: second.id, who: "other" });
      assert.equal(reset.input_version, stored.input_version + 1);
      assert.deepEqual(reset.preferences, defaults);
      await call("POST", participantsPath, { sessionId, who: "other", status: 404, body: point });
      await call("POST", participantsPath, { sessionId, status: 400, body: { ...point, latitude: 91 } });
      await call("POST", participantsPath, { sessionId, status: 400, body: { ...point, display_name: "x".repeat(61) } });
      await call("POST", participantsPath, { sessionId, status: 400, body: { ...point, user_id: ids.other } });
      const added = await call("POST", participantsPath, {
        sessionId, status: 201, body: { ...point, display_name: "other", approximate_area: "Public landmark" },
      });
      const guest = added.standalone_participants[1];
      assert.equal(guest.participant_type, "MANUAL");
      assert.equal(guest.display_name, "other");
      assert.equal(guest.latitude, 30.041);
      assert.equal(guest.longitude, 31.251);
      assert.equal(added.input_version, ownerReady.input_version + 1);
      assert.equal(added.calculation_status, "ROUTING_UNAVAILABLE");
      assert.deepEqual(await call("GET", participantsPath, { sessionId }), added.standalone_participants);

      const participantId = guest.id as string;
      await call("PATCH", participantPath, { sessionId, participantId: sessionId, status: 404, body: { display_name: "Owner" } });
      await call("PATCH", participantPath, { sessionId: second.id, participantId, who: "other", status: 404, body: { display_name: "Guest" } });
      await call("PATCH", participantPath, { sessionId, participantId, status: 400, body: { latitude: 1 } });
      const changed = await call("PATCH", participantPath, {
        sessionId, participantId, body: { display_name: null, transportation_mode: "WALKING" },
      });
      assert.equal(changed.input_version, added.input_version + 1);
      assert.equal(changed.standalone_participants[1].display_name, null);
      assert.equal(changed.standalone_participants[1].transportation_mode, "WALKING");
      const removed = await call("DELETE", participantPath, { sessionId, participantId });
      assert.equal(removed.input_version, changed.input_version + 1);
      assert.equal(removed.standalone_participants.length, 1);

      const limit = created[0].manual_participant_limit as number;
      for (let i = 1; i < limit; i++) {
        await call("POST", participantsPath, { sessionId, status: 201, body: point });
      }
      // At least one of two concurrent requests loses the final slot.
      const finalSlot = await Promise.all([0, 1].map(async () => {
        const response = await fetch(url + participantsPath.replace("{sessionId}", sessionId), {
          method: "POST", headers: { authorization: "Bearer owner", "content-type": "application/json" },
          body: JSON.stringify(point),
        });
        responseAssertion(spec, spec.paths[participantsPath].post, response.status, "application/json", await response.json());
        return response.status;
      }));
      assert.deepEqual(finalSlot.sort(), [201, 409]);
      const full = await call("PATCH", sessionPath + "/preferences", {
        sessionId, body: { optimization: "SHORTEST_TOTAL_TIME" },
      });
      assert.equal(full.standalone_participants.length, limit + 1);
      assert.equal(full.calculation_status, "ROUTING_UNAVAILABLE");

      await prisma.meetup_sessions.update({ where: { id: sessionId }, data: { expires_at: new Date(0) } });
      await call("GET", participantsPath, { sessionId, status: 409 });
      assert.equal(await prisma.meetup_manual_participants.count({ where: { meetup_session_id: sessionId } }), 0);
      const expired = await call("GET", sessionPath, { sessionId });
      assert.equal(expired.status, "EXPIRED");
      assert.deepEqual(expired.standalone_participants, []);

      const fresh = await call("POST", standalonePath);
      assert.notEqual(fresh.id, sessionId);
      await call("POST", participantsPath, { sessionId: fresh.id, status: 201, body: point });
      await prisma.meetup_sessions.update({ where: { id: fresh.id }, data: { expires_at: new Date(0) } });
      await new MeetupSessionRepository().cleanupExpired();
      assert.equal(await prisma.meetup_manual_participants.count({ where: { meetup_session_id: fresh.id } }), 0);

      await call("POST", participantsPath, { sessionId: second.id, status: 201, who: "other", body: point });
      await prisma.meetup_sessions.delete({ where: { id: second.id } });
      assert.equal(await prisma.meetup_manual_participants.count({ where: { meetup_session_id: second.id } }), 0);

      const last = await call("POST", standalonePath);
      await call("POST", participantsPath, { sessionId: last.id, status: 201, body: point });
      assert.deepEqual((await call("DELETE", sessionPath, { sessionId: last.id })).standalone_participants, []);
      assert.equal(await prisma.meetup_manual_participants.count({ where: { meetup_session_id: last.id } }), 0);
    });
    assert.deepEqual(await prisma.users.findMany({ where: { id: { in: Object.values(ids) } }, orderBy: { id: "asc" } }), profilesBefore);
    assert.deepEqual(await relatedCounts(), countsBefore);
  } finally {
    await prisma.users.deleteMany({ where: { id: { in: Object.values(ids) } } });
    await deleteApp(firebase);
  }
});

test("Swagger verifies roster, privacy, concurrent initialization, scope, expiry and invalidation",
  { skip: !isolatedDatabase, timeout: 60_000 }, async t => {
  const names = ["owner", "member", "pending", "outsider"] as const;
  type Identity = typeof names[number];
  const ids = Object.fromEntries(names.map(name => [name, "meetup-" + randomUUID()])) as Record<Identity, string>;
  const phones = Object.fromEntries(names.map((name, i) => [name, `+201${i}${randomInt(10000000, 99999999)}`]));
  const firebase = initializeApp({ projectId: "demo-yalla-meetup" });
  t.mock.method(getAuth(firebase), "verifyIdToken", async (token: Identity) => ({
    uid: ids[token], firebase: { sign_in_provider: "custom" },
  }));
  const groupId = randomUUID();
  const otherGroup = randomUUID();
  const placeId = randomUUID();
  const point = { latitude: 30.04321, longitude: 31.25432 };
  try {
    await prisma.users.createMany({ data: names.map(name => ({ id: ids[name], name, phone: phones[name] })) });
    await prisma.groups.createMany({ data: [groupId, otherGroup].map(id => ({ id, name: "Meetup fixture", created_by: ids.owner })) });
    await prisma.group_members.createMany({ data: [
      { group_id: groupId, user_id: ids.owner, role: "owner" },
      { group_id: groupId, user_id: ids.member },
      { group_id: otherGroup, user_id: ids.owner, role: "owner" },
    ] });
    await prisma.group_invitations.create({ data: { group_id: groupId, user_id: ids.pending,
      invited_by_user_id: ids.owner, invited_phone: phones.pending, expires_at: new Date(Date.now() + 60_000) } });
    const outings = await Promise.all([groupId, groupId, otherGroup].map(group_id =>
      prisma.outings.create({ data: { title: "Meetup fixture", group_id, created_by: ids.owner } })));
    const originalOutingCount = await prisma.outings.count({ where: { group_id: groupId } });
    await prisma.places.create({ data: { id: placeId, name: "Catalog fixture", district: "Maadi", ...point } });
    const saved = await prisma.saved_locations.create({ data: { ...point, user_id: ids.member,
      name: "Private home", address: "Private address", approximate_area: "Private area",
      location_type: "home", place_id: placeId, preferred_transportation_mode: "METRO" } });
    await prisma.default_starting_locations.create({ data: { user_id: ids.member, saved_location_id: saved.id } });
    await prisma.user_location_privacy.create({ data: { user_id: ids.member,
      automatic_meetup_location_usage_enabled: true, location_usage_consent_at: new Date(),
      consent_policy_version: locationUsagePolicyVersion } });

    await withApi(app, async url => {
      const spec = await (await fetch(url + "/api-docs/openapi.json")).json() as OpenApi;
      async function call(method: string, path: string, who: Identity, status = 200, body?: unknown, id = groupId) {
        const operation = spec.paths[path][method.toLowerCase()];
        const response = await fetch(url + path.replace(/\{\w+\}/, id), { method,
          headers: { authorization: "Bearer " + who, ...(body === undefined ? {} : { "content-type": "application/json" }) },
          ...(body === undefined ? {} : { body: JSON.stringify(body) }) });
        const payload = await response.json();
        assert.equal(response.status, status, `${method} ${path}: ${JSON.stringify(payload)}`);
        responseAssertion(spec, operation, status, "application/json", payload);
        if (response.ok) {
          assert.equal(response.headers.get("cache-control"), "private, no-store");
          assert.doesNotMatch(JSON.stringify(payload),
            /latitude|longitude|30\.04321|31\.25432|Private home|Private address|Private area|METRO|authorization_revision|input_digest/);
        }
        return payload.data;
      }

      await call("POST", groupPath, "pending", 403);
      await call("POST", groupPath, "outsider", 403);
      await call("POST", groupPath, "member", 400, { participants: [ids.member] });
      await call("POST", groupPath, "member", 404, { outing_id: outings[2].id });
      const concurrent = await Promise.all(Array.from({ length: 6 }, () => call("POST", groupPath, "member")));
      const general = concurrent[0];
      assert.ok(concurrent.every(value => value.id === general.id && value.input_version === 1));
      assert.equal(general.can_manage, true);
      assert.equal(general.calculation_status, "ROUTING_UNAVAILABLE");
      assert.deepEqual(general.preferences, defaultMeetupPreferences());
      assert.deepEqual(general.readiness, {
        intended: 2, usable: 1, requiring_setup: 1, status: "PARTIAL",
        participants: [...general.readiness.participants].map(({ display_name }: { display_name: string }) =>
          display_name === "member" ? { display_name, is_self: true, status: "READY", district: "Maadi" }
            : { display_name: "owner", is_self: false, status: "SETUP_REQUIRED", district: null }),
      });
      assert.deepEqual(general.readiness.participants.map((p: { display_name: string }) => p.display_name).sort(), ["member", "owner"]);
      assert.equal((await call("POST", groupPath, "owner")).id, general.id);
      const specific = await Promise.all(outings.slice(0, 2).map(outing =>
        call("POST", groupPath, "owner", 200, { outing_id: outing.id })));
      assert.equal(new Set([general.id, ...specific.map(value => value.id)]).size, 3);
      assert.equal(await prisma.outings.count({ where: { group_id: groupId } }), originalOutingCount);

      await call("GET", sessionPath, "pending", 403, undefined, general.id);
      assert.deepEqual(await call("GET", preferencesPath, "owner", 200, undefined, general.id), general.preferences);
      await call("PUT", preferencesPath, "owner", 403, general.preferences, general.id);
      await call("POST", resetPath, "owner", 403, undefined, general.id);
      await call("PATCH", sessionPath + "/preferences", "owner", 403, { optimization: "BALANCED" }, general.id);
      await call("DELETE", sessionPath, "owner", 403, undefined, general.id);
      await call("POST", sessionPath + "/refresh", "member", 400, { remove: [ids.owner] }, general.id);
      const settings = await call("PATCH", sessionPath + "/preferences", "member", 200,
        { optimization: "SHORTEST_TOTAL_TIME" }, general.id);
      assert.equal(settings.input_version, 2);
      assert.equal(settings.preferences.travelFairnessMode, "FASTEST_OVERALL");
      assert.equal((await call("GET", preferencesPath, "owner", 200, undefined, general.id)).travelFairnessMode, "FASTEST_OVERALL");

      await prisma.user_location_privacy.update({ where: { user_id: ids.member }, data: { location_visibility: "HIDDEN" } });
      const hidden = await call("GET", sessionPath + "/readiness", "owner", 200, undefined, general.id);
      assert.equal(hidden.participants.find((p: { display_name: string }) => p.display_name === "member").district, null);
      const hiddenSession = await call("GET", sessionPath, "owner", 200, undefined, general.id);
      assert.equal(hiddenSession.input_version, settings.input_version + 1);
      await prisma.user_location_group_exclusions.create({ data: { user_id: ids.member, group_id: groupId } });
      const excluded = await call("POST", sessionPath + "/refresh", "owner", 200, undefined, general.id);
      assert.equal(excluded.input_version, hiddenSession.input_version + 1);
      assert.equal(excluded.readiness.status, "INSUFFICIENT_DATA");
      await prisma.group_members.delete({ where: { group_id_user_id: { group_id: groupId, user_id: ids.member } } });
      await call("GET", sessionPath, "member", 403, undefined, general.id);
      await call("POST", groupPath, "member", 403);
      const removed = await call("GET", sessionPath, "owner", 200, undefined, general.id);
      assert.equal(removed.input_version, excluded.input_version + 1);
      assert.equal(removed.readiness.intended, 1);
      assert.equal((await call("DELETE", sessionPath, "owner", 200, undefined, specific[0].id)).status, "CANCELLED");
      assert.equal((await call("GET", sessionPath, "owner", 200, undefined, specific[1].id)).status, "ACTIVE");
      await prisma.outings.update({ where: { id: outings[1].id }, data: { group_id: otherGroup } });
      await call("GET", sessionPath, "owner", 404, undefined, specific[1].id);
      const moved = await call("POST", groupPath, "owner", 200, { outing_id: outings[1].id }, otherGroup);
      assert.notEqual(moved.id, specific[1].id);

      await prisma.meetup_sessions.update({ where: { id: general.id }, data: { expires_at: new Date(0) } });
      assert.equal((await call("GET", sessionPath, "owner", 200, undefined, general.id)).status, "EXPIRED");
      assert.notEqual((await call("POST", groupPath, "owner")).id, general.id);
    });
  } finally {
    await prisma.$transaction(async tx => {
      await tx.$executeRaw`SET CONSTRAINTS ALL DEFERRED`;
      await tx.outings.deleteMany({ where: { group_id: { in: [groupId, otherGroup] } } });
    });
    await prisma.groups.deleteMany({ where: { id: { in: [groupId, otherGroup] } } });
    await prisma.users.deleteMany({ where: { id: { in: Object.values(ids) } } });
    await prisma.places.deleteMany({ where: { id: placeId } });
    await deleteApp(firebase);
  }
});
