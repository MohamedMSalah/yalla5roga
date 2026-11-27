
import assert from "node:assert/strict";
import { randomInt, randomUUID } from "node:crypto";
import { test } from "node:test";
import { deleteApp, initializeApp } from "firebase-admin/app";
import { getAuth } from "firebase-admin/auth";
import app, { swaggerCoverage } from "../src/app.js";
import { prisma } from "../src/config/database.js";
import { MeetupSessionRepository } from "../src/repositories/meetups/meetup-session.repository.js";
import { locationUsagePolicyVersion } from "../src/types/users/location-privacy.types.js";
import { isolatedDatabase } from "./support/isolated-database.js";
import { responseAssertion, withApi, type OpenApi } from "./support/http-fixture.js";

const meetup = "/api/smart-meetups/{sessionId}";
const opening = "/api/groups/{groupId}/smart-meetup";
const outing = "/api/outings/{outingId}/my-starting-location";
const starting = meetup + "/my-starting-location";
const consent = "/api/users/me/location-consent";
const exclusion = consent + "/excluded-groups/{groupId}";

test("served Swagger documents all six authenticated override operations", async () => {
  assert.deepEqual(swaggerCoverage.undocumented, []);
  assert.deepEqual(swaggerCoverage.unregistered, []);
  await withApi(app, async url => {
    const spec = await (await fetch(url + "/api-docs/openapi.json")).json() as OpenApi;
    for (const path of [starting, outing]) {
      for (const method of ["GET", "PUT", "DELETE"]) {
        const operation = spec.paths[path][method.toLowerCase()];
        assert.deepEqual(operation.security, [{ bearerAuth: [] }]);
        const response = await fetch(url + path.replace(/\{\w+\}/, randomUUID()), { method });
        assert.equal(response.status, 401);
        responseAssertion(spec, operation, 401, "application/json", await response.json());
      }
    }
  });
});

test("overrides enforce context, owner, consent, input versions and cleanup through the served API",
  { skip: !isolatedDatabase, timeout: 60_000 }, async t => {
  const ids = { owner: "override-" + randomUUID(), member: "override-" + randomUUID() };
  type Identity = keyof typeof ids;
  const firebase = initializeApp({ projectId: "demo-yalla-overrides" });
  t.mock.method(getAuth(firebase), "verifyIdToken", async (token: Identity) => ({
    uid: ids[token], firebase: { sign_in_provider: "custom" },
  }));
  const group = randomUUID();
  const place = randomUUID();
  const groupOuting = randomUUID();
  const guestOuting = randomUUID();
  const votingOuting = randomUUID();
  const otherGroup = randomUUID();
  const now = Date.now();
  const scheduled = new Date(now + 7_200_000);
  const point = { latitude: 30.01523, longitude: 31.01523 };
  const tempPoint = { latitude: 29.95, longitude: 31.22 };
  const venue = { location_name: "Confirmed venue", location_latitude: 30.06, location_longitude: 31.29 };

  try {
    await prisma.users.createMany({ data: Object.entries(ids).map(([name, id], i) => ({
      id, name, phone: `+201${i}${randomInt(10000000, 99999999)}`, default_transportation_mode: "CAR",
    })) });
    await prisma.groups.createMany({ data: [group, otherGroup].map(id => ({ id, name: "Fixture", created_by: ids.owner })) });
    await prisma.group_members.createMany({ data: [
      { group_id: group, user_id: ids.owner, role: "owner" }, { group_id: group, user_id: ids.member },
    ] });
    await prisma.outings.createMany({ data: [
      { id: votingOuting, title: "Voting fixture", group_id: group, created_by: ids.owner,
        scheduled_at: scheduled, vote_ends_at: new Date(now + 3_600_000), status: "voting" },
      { id: groupOuting, title: "Group fixture", group_id: group, created_by: ids.owner,
        scheduled_at: scheduled, status: "confirmed", ...venue },
      { id: guestOuting, title: "Guest fixture", type: "special_event", occasion: "birthday",
        created_by: ids.owner, scheduled_at: scheduled, status: "confirmed", ...venue },
    ] });
    await prisma.outing_guests.create({ data: { outing_id: guestOuting, user_id: ids.member } });
    await prisma.places.create({ data: { id: place, name: "Fixture bookmark", ...tempPoint } });
    await prisma.saved_places.create({ data: { user_id: ids.member, place_id: place, preferred_transportation_mode: "WALKING" } });
    const personal = await prisma.saved_locations.create({ data: { ...point, user_id: ids.member, name: "Home fixture",
      location_type: "home", preferred_transportation_mode: "METRO" } });
    const otherPersonal = await prisma.saved_locations.create({ data: { ...tempPoint, user_id: ids.member,
      name: "Work fixture", location_type: "work" } });
    const defaultBefore = await prisma.default_starting_locations.create({ data: { user_id: ids.member, saved_location_id: personal.id } });

    await withApi(app, async url => {
      const spec = await (await fetch(url + "/api-docs/openapi.json")).json() as OpenApi;
      async function call(method: string, path: string, id: string, who: Identity = "member", status = 200, body?: unknown) {
        const response = await fetch(url + path.replace(/\{\w+\}/, id), { method,
          headers: { authorization: "Bearer " + who, ...(body === undefined ? {} : { "content-type": "application/json" }) },
          ...(body === undefined ? {} : { body: JSON.stringify(body) }),
        });
        const payload = await response.json();
        assert.equal(response.status, status, `${method} ${path}: ${JSON.stringify(payload)}`);
        responseAssertion(spec, spec.paths[path][method.toLowerCase()], status, "application/json", payload);
        if (response.ok) assert.equal(response.headers.get("cache-control"), "private, no-store");
        return payload.data;
      }
      const session = (await call("POST", opening, group, "owner")).id;
      const quick = (await call("POST", "/api/smart-meetups/standalone", "", "member")).id;
      const linked = (await call("POST", opening, group, "owner", 200, { outing_id: groupOuting })).id;
      const baseline = await call("GET", starting, session);
      const version = baseline.consent_policy_version;
      const manual = { location_source: "MANUAL_POINT", ...tempPoint, consent_policy_version: version };
      const savedLocation = { location_source: "PERSONAL_LOCATION", personal_location_id: otherPersonal.id, consent_policy_version: version };
      const bookmark = { location_source: "SAVED_PLACE", saved_place_id: place, consent_policy_version: version };
      const transportation = { location_source: "DEFAULT", transportation_mode: "MOTORCYCLE" };
      assert.equal(baseline.status, "CONSENT_REQUIRED");
      assert.equal(baseline.location, null);
      await call("PUT", starting, session, "member", 400, { location_source: "MANUAL_POINT", ...tempPoint });
      await call("PUT", starting, session, "member", 400, { ...manual, latitude: 91 });
      await call("PUT", starting, session, "member", 400, { ...manual, personal_location_id: personal.id });
      await call("PUT", starting, session, "member", 409, { ...manual, consent_policy_version: "old-policy" });
      await call("PUT", starting, quick, "owner", 404, manual);
      await call("PUT", starting, session, "owner", 400, { ...manual, user_id: ids.member });
      await call("PUT", starting, session, "owner", 404, savedLocation);
      await call("PUT", starting, session, "owner", 404, bookmark);
      await call("PUT", outing, guestOuting, "member", 403, manual);

      const groupOverride = await call("PUT", starting, session, "member", 200, manual);
      assert.equal(groupOverride.location.temporary, true);
      assert.equal(groupOverride.location.latitude, tempPoint.latitude);
      assert.equal(groupOverride.transportation.mode, "CAR");
      assert.equal(groupOverride.input_version, baseline.input_version + 1);
      assert.deepEqual(await call("PUT", starting, session, "member", 200, manual), groupOverride);
      const ready = await call("GET", meetup, session, "owner");
      assert.equal(ready.input_version, groupOverride.input_version);
      assert.equal(ready.calculation_status, "ROUTING_UNAVAILABLE");
      assert.equal(ready.readiness.usable, 1);
      assert.doesNotMatch(JSON.stringify(ready), /latitude|longitude|Home fixture|29.95/);
      for (const [path, id] of [[starting, quick], [starting, linked], [outing, groupOuting]]) {
        assert.equal((await call("GET", path, id)).location, null);
      }
      assert.equal((await call("GET", starting, session, "owner")).override, null);
      await call("DELETE", starting, session, "owner");
      assert.equal((await call("GET", starting, session)).override.location_source, "MANUAL_POINT");

      const quickOverride = await call("PUT", starting, quick, "member", 200, savedLocation);
      assert.equal(quickOverride.location.name, otherPersonal.name);
      assert.equal(quickOverride.override.latitude, null);
      assert.equal((await call("GET", meetup, quick)).standalone_participants[0].latitude, tempPoint.latitude);
      const beforeOuting = await call("GET", outing, groupOuting);
      const outingOverride = await call("PUT", outing, groupOuting, "member", 200, bookmark);
      assert.deepEqual(outingOverride.transportation, { mode: "WALKING", source: "saved_location" });
      assert.equal(outingOverride.override.longitude, null);
      assert.equal(outingOverride.input_version, beforeOuting.input_version + 1);
      assert.equal((await call("GET", starting, linked)).override, null);
      const confirmed = await prisma.outings.findUniqueOrThrow({ where: { id: groupOuting }, select: {
        location_name: true, location_latitude: true, location_longitude: true, winning_option_id: true,
      } });
      assert.deepEqual(confirmed, { ...venue, winning_option_id: null });

      await prisma.outing_vote_options.createMany({ data: ["Candidate A", "Candidate B"].map(label => ({
        outing_id: votingOuting, label,
      })) });
      const candidates = () => prisma.outing_vote_options.findMany({
        where: { outing_id: votingOuting }, orderBy: { id: "asc" },
      });
      const beforeCandidates = await candidates();
      const duringVoting = await call("PUT", outing, votingOuting, "member", 200, manual);
      assert.deepEqual(await candidates(), beforeCandidates);
      const newEnd = new Date(now + 10_800_000);
      await prisma.outings.update({ where: { id: votingOuting }, data: { ends_at: newEnd } });
      const shortened = await call("GET", outing, votingOuting);
      assert.equal(shortened.override.expires_at, newEnd.toISOString());
      assert.equal(shortened.input_version, duringVoting.input_version + 1);
      const votingSession = (await call("POST", opening, group, "owner", 200, { outing_id: votingOuting })).id;
      await call("PUT", starting, votingSession, "owner", 200, manual);
      await prisma.outings.update({ where: { id: votingOuting }, data: { group_id: otherGroup } });
      await call("GET", outing, votingOuting, "member", 403);
      await call("GET", starting, votingSession, "owner", 404);
      assert.equal(await prisma.starting_location_overrides.count({
        where: { OR: [{ outing_id: votingOuting }, { meetup_session_id: votingSession }] },
      }), 0);
      assert.deepEqual(await candidates(), beforeCandidates);
      await prisma.outings.update({ where: { id: votingOuting }, data: { group_id: group } });
      await call("PUT", outing, votingOuting, "member", 200, manual);
      await prisma.outings.update({ where: { id: votingOuting }, data: { status: "cancelled" } });
      await call("GET", outing, votingOuting, "member", 409);
      assert.equal(await prisma.starting_location_overrides.count({ where: { outing_id: votingOuting } }), 0);

      await call("PUT", consent, "", "member", 200, { consent_policy_version: locationUsagePolicyVersion });
      assert.equal((await call("GET", outing, groupOuting, "owner")).location, null);
      const outingDefaultAuthorization = { location_source: "DEFAULT", consent_policy_version: version };
      await call("PUT", outing, groupOuting, "member", 400, { location_source: "DEFAULT" });
      await call("PUT", outing, groupOuting, "member", 409, {
        ...outingDefaultAuthorization, consent_policy_version: locationUsagePolicyVersion,
      });
      const confirmedOverride = await call("PUT", outing, guestOuting, "owner", 200, transportation);
      assert.equal(confirmedOverride.location, null);
      assert.equal(confirmedOverride.transportation.mode, "MOTORCYCLE");
      await call("DELETE", outing, guestOuting, "owner");
      const reset = await call("DELETE", starting, session);
      assert.equal(reset.location.name, personal.name);
      assert.equal(reset.location.temporary, false);
      assert.equal(reset.override, null);
      assert.equal(reset.transportation.mode, "METRO");
      const modeOnly = await call("PUT", starting, session, "member", 200, transportation);
      assert.equal(modeOnly.location.temporary, false);
      assert.deepEqual(modeOnly.transportation, { mode: "MOTORCYCLE", source: "temporary_override" });
      assert.deepEqual(await prisma.default_starting_locations.findUnique({ where: { user_id: ids.member } }), defaultBefore);
      await prisma.saved_locations.delete({ where: { id: otherPersonal.id } });
      const afterLocationDelete = await call("GET", starting, quick);
      assert.equal(afterLocationDelete.override, null);
      assert.equal(afterLocationDelete.location.name, personal.name);
      assert.equal(afterLocationDelete.input_version, quickOverride.input_version + 1);
      await prisma.saved_places.delete({ where: { user_id_place_id: { user_id: ids.member, place_id: place } } });
      const afterBookmarkDelete = await call("GET", outing, groupOuting);
      assert.equal(afterBookmarkDelete.override, null);
      assert.equal(afterBookmarkDelete.input_version, outingOverride.input_version + 1);
      assert.equal(afterBookmarkDelete.location, null);
      assert.equal(afterBookmarkDelete.status, "CONSENT_REQUIRED");
      const authorizedDefault = await call("PUT", outing, groupOuting, "member", 200, outingDefaultAuthorization);
      assert.equal(authorizedDefault.location.name, personal.name);
      assert.equal(authorizedDefault.location.temporary, false);
      assert.equal(authorizedDefault.transportation.mode, "METRO");
      const clearedOuting = await call("DELETE", outing, groupOuting);
      assert.equal(clearedOuting.override, null);
      assert.equal(clearedOuting.location, null);

      await call("PUT", starting, linked, "member", 200, manual);
      await call("PUT", outing, groupOuting, "member", 200, manual);
      await call("PUT", exclusion, group);
      assert.equal((await call("GET", starting, linked)).status, "GROUP_EXCLUDED");
      assert.equal(await prisma.starting_location_overrides.count({ where: { user_id: ids.member } }), 0);
      await call("PUT", starting, session, "member", 403, manual);
      await call("PUT", outing, groupOuting, "member", 403, manual);
      await call("DELETE", exclusion, group);

      await call("PUT", starting, session, "member", 200, manual);
      await call("PUT", starting, quick, "member", 200, manual);
      await call("DELETE", consent, "");
      assert.equal((await call("GET", starting, quick)).location, null);
      assert.equal((await call("GET", starting, session)).location, null);
      assert.equal(await prisma.starting_location_overrides.count({ where: { user_id: ids.member } }), 0);

      await call("PUT", starting, session, "member", 200, manual);
      await call("PUT", outing, groupOuting, "member", 200, manual);
      await prisma.group_members.delete({ where: { group_id_user_id: { group_id: group, user_id: ids.member } } });
      assert.equal(await prisma.starting_location_overrides.count({ where: { user_id: ids.member } }), 0);
      await call("GET", starting, session, "member", 403);
      await call("GET", outing, groupOuting, "member", 403);

      const guestKey = { outing_id_user_id: { user_id: ids.member, outing_id: guestOuting } };
      await prisma.outing_guests.update({ where: guestKey, data: { status: "accepted" } });
      await call("PUT", outing, guestOuting, "member", 200, manual);
      await prisma.starting_location_overrides.update({
        where: { user_id_outing_id: { user_id: ids.member, outing_id: guestOuting } },
        data: { created_at: new Date(now - 2000), expires_at: new Date(now - 1000) },
      });
      const beforeSweep = await call("GET", outing, guestOuting);
      assert.equal(beforeSweep.override, null);
      await new MeetupSessionRepository().cleanupExpired();
      assert.equal(await prisma.starting_location_overrides.count({ where: { outing_id: guestOuting } }), 0);
      assert.equal((await call("GET", outing, guestOuting)).input_version, beforeSweep.input_version + 1);
      await call("PUT", outing, guestOuting, "member", 200, manual);
      await prisma.outing_guests.update({ where: guestKey, data: { status: "declined" } });
      assert.equal(await prisma.starting_location_overrides.count({ where: { user_id: ids.member } }), 0);
      await call("DELETE", outing, guestOuting, "member", 403);

      await call("PUT", starting, quick, "member", 200, manual);
      await call("PUT", outing, groupOuting, "owner", 200, manual);
      await call("PUT", starting, linked, "owner", 200, manual);
      await prisma.outings.update({ where: { id: groupOuting }, data: { status: "past" } });
      assert.equal(await prisma.starting_location_overrides.count({ where: { user_id: ids.owner } }), 0);
      await call("GET", outing, groupOuting, "owner", 409);
      await call("GET", starting, linked, "owner", 409);
      await prisma.meetup_sessions.update({ where: { id: quick }, data: { expires_at: new Date(now - 1000) } });
      await new MeetupSessionRepository().cleanupExpired();
      await call("GET", starting, quick, "member", 409);
      assert.equal(await prisma.starting_location_overrides.count({ where: { user_id: ids.member } }), 0);

      const nextQuick = (await call("POST", "/api/smart-meetups/standalone", "")).id;
      const initialVersion = (await call("GET", starting, nextQuick)).input_version;
      const changed = await Promise.all(["WALKING", "METRO"].map(transportation_mode =>
        call("PUT", starting, nextQuick, "member", 200, { ...manual, transportation_mode })));
      assert.deepEqual(changed.map(reply => reply.input_version).sort((a, b) => a - b),
        [initialVersion + 1, initialVersion + 2]);
      assert.equal(await prisma.starting_location_overrides.count({
        where: { user_id: ids.member, meetup_session_id: nextQuick },
      }), 1);
      await call("DELETE", meetup, nextQuick);
      assert.equal(await prisma.starting_location_overrides.count({ where: { user_id: ids.member } }), 0);
      await call("PUT", starting, session, "owner", 200, manual);
      await prisma.outing_guests.update({ where: guestKey, data: { status: "accepted" } });
      await call("PUT", outing, guestOuting, "member", 200, manual);
      await prisma.users.delete({ where: { id: ids.member } });
      assert.equal(await prisma.starting_location_overrides.count({ where: { user_id: ids.member } }), 0);
    });
  } finally {
    await prisma.outings.deleteMany({ where: { id: { in: [groupOuting, guestOuting, votingOuting] } } });
    await prisma.groups.deleteMany({ where: { id: { in: [group, otherGroup] } } });
    await prisma.users.deleteMany({ where: { id: { in: Object.values(ids) } } });
    await prisma.places.deleteMany({ where: { id: place } });
    await deleteApp(firebase);
  }
});
