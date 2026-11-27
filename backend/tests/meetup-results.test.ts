import assert from "node:assert/strict";
import { randomInt, randomUUID } from "node:crypto";
import { test } from "node:test";
import { deleteApp, initializeApp } from "firebase-admin/app";
import { getAuth } from "firebase-admin/auth";
import app from "../src/app.js";
import { prisma } from "../src/config/database.js";
import { locationUsagePolicyVersion } from "../src/types/users/location-privacy.types.js";
import { PublishRoutedMeetupResultsUseCase } from "../src/usecases/meetups/meetup-result.usecases.js";
import { MeetupSessionWorkflow } from "../src/usecases/meetups/meetup-session.usecases.js";
import { isolatedDatabase } from "./support/isolated-database.js";
import { responseAssertion, withApi, type OpenApi } from "./support/http-fixture.js";

const sessionPath = "/api/smart-meetups/{sessionId}";
const resultPath = sessionPath + "/results";
const refreshPath = sessionPath + "/calculate";
const calculationPath = sessionPath + "/calculations/{calculationId}";

test("Smart Meetup results enforce scoped access, publication, privacy and stale handoff",
  { skip: !isolatedDatabase, timeout: 60_000 }, async t => {
  const identities = ["owner", "member", "outsider"] as const;
  type Identity = typeof identities[number];
  const users = Object.fromEntries(identities.map(name => [name, "result-" + randomUUID()])) as Record<Identity, string>;
  const firebase = initializeApp({ projectId: "demo-yalla-meetup-results" });
  t.mock.method(getAuth(firebase), "verifyIdToken", async (name: Identity) => ({
    uid: users[name], firebase: { sign_in_provider: "custom" },
  }));
  const groupId = randomUUID();
  const placeIds = Array.from({ length: 8 }, () => randomUUID());
  const [placeId, ...otherPlaces] = placeIds;
  const location = { latitude: 30, longitude: 31 };
  const privateOrigin = { latitude: 30.14682, longitude: 31.21846 };
  const phones = identities.map((_, i) => `+201${i}${randomInt(10000000, 99999999)}`);
  const [owner, member, outsider] = identities.map(name => users[name]);
  try {
    await prisma.users.createMany({ data: identities.map((name, i) => ({
      id: users[name], name, phone: phones[i],
    })) });
    await prisma.groups.create({ data: { id: groupId, name: "Result fixture", created_by: users.owner } });
    await prisma.group_members.createMany({ data: [
      { group_id: groupId, user_id: users.owner, role: "owner" },
      { group_id: groupId, user_id: users.member },
    ] });
    await prisma.group_invitations.create({ data: {
      group_id: groupId, user_id: outsider, invited_by_user_id: owner,
      invited_phone: phones[2], expires_at: new Date(Date.now() + 60 * 60_000),
    } });
    await prisma.places.createMany({ data: placeIds.map((id, index) => ({
      id, name: "Fixture venue " + index, ...location,
      price_level: index === 7 ? "expensive" : "budget", is_active: index !== 6,
    })) });
    await prisma.place_reviews.createMany({ data: [
      { place_id: placeId, user_id: users.owner, rating: 4 },
      { place_id: placeId, user_id: users.member, rating: 5 },
    ] });

    await withApi(app, async base => {
      const spec = await (await fetch(base + "/api-docs/openapi.json")).json() as OpenApi;
      async function call(method: string, path: string, {
        who = "owner", status = 200, sessionId = randomUUID(), calculationId = randomUUID(), body, outingId,
      }: { who?: Identity; status?: number; sessionId?: string; calculationId?: string; body?: unknown; outingId?: string } = {}) {
        const response = await fetch(base + path.replace("{groupId}", groupId)
          .replace("{sessionId}", sessionId).replace("{calculationId}", calculationId).replace("{id}", outingId ?? ""), {
          method, headers: { authorization: "Bearer " + who,
            ...(body === undefined ? {} : { "content-type": "application/json" }) },
          ...(body === undefined ? {} : { body: JSON.stringify(body) }),
        });
        const payload = await response.json();
        assert.equal(response.status, status, JSON.stringify(payload));
        responseAssertion(spec, spec.paths[path][method.toLowerCase()], status, "application/json", payload);
        if (response.ok && !path.startsWith("/api/outings")) {
          assert.equal(response.headers.get("cache-control"), "private, no-store");
        }
        return response.ok ? payload.data : payload;
      }

      const outingPath = "/api/outings";
      const outingRequest = {
        title: "Fixture outing",
        scheduled_at: new Date(Date.now() + 24 * 60 * 60_000).toISOString(),
        vote_deadline_hours: 3,
        group_id: groupId,
      };
      function selection(sessionId: string, calculationId: string, placeIds: string[]) {
        return { session_id: sessionId, calculation_id: calculationId, place_ids: placeIds };
      }
      const fixedRequest = {
        ...outingRequest, create_request_key: randomUUID(),
        location_place_id: placeId, location_name: "Untrusted snapshot",
        location_area: "Untrusted area", location_address: "Untrusted address",
        location_latitude: privateOrigin.latitude, location_longitude: privateOrigin.longitude,
      };
      const create = (body: unknown, status = 201, who: Identity = "owner") =>
        call("POST", outingPath, { body, status, who });

      const quick = await call("POST", "/api/smart-meetups/standalone");
      const sessionId = quick.id as string;
      const group = await call("POST", "/api/groups/{groupId}/smart-meetup");
      for (const path of [resultPath, refreshPath, calculationPath]) {
        const method = path === refreshPath ? "POST" : "GET";
        await call(method, path, { sessionId, who: "member", status: 404 });
        await call(method, path, { sessionId: group.id, who: "outsider", status: 403 });
      }
      assert.equal((await call("GET", resultPath, { sessionId: group.id, who: "member" })).status, "INSUFFICIENT_DATA");

      const baseOptions = { sessionId };
      assert.equal((await call("GET", resultPath, baseOptions)).status, "INSUFFICIENT_DATA");
      const guests = await call("POST", sessionPath + "/participants", {
        ...baseOptions, status: 201, body: { ...location, transportation_mode: "CAR" },
      });
      const participantId = guests.standalone_participants.find((p: { participant_type: string }) =>
        p.participant_type === "MANUAL").id;
      const configured = await call("PUT", sessionPath + "/preferences", {
        ...baseOptions, body: { ...quick.preferences, budgetLevels: ["AFFORDABLE"] },
      });
      const unavailable = await call("GET", resultPath, baseOptions);
      assert.equal(unavailable.status, "ROUTING_UNAVAILABLE");
      assert.equal(unavailable.inputVersion, configured.input_version);
      assert.equal(unavailable.calculation, null);
      assert.deepEqual(unavailable.recommendations, []);
      assert.equal(await prisma.meetup_calculations.count({ where: { meetup_session_id: sessionId } }), 0);

      const refreshed = await Promise.all([0, 1, 2].map(() => call("POST", refreshPath, baseOptions)));
      const calculationId = refreshed[0].calculation.id as string;
      assert.ok(refreshed.every(result => result.calculation.id === calculationId));
      assert.equal(await prisma.outings.count({ where: { group_id: groupId } }), 0);
      const quickRequest = {
        ...fixedRequest, smart_meetup_selection: selection(sessionId, calculationId, [placeId]),
      };
      assert.equal((await create(quickRequest, 409)).code, "stale_meetup_result");
      await create(quickRequest, 404, "member");
      assert.equal(refreshed[0].intendedParticipantCount, 2);
      assert.equal(refreshed[0].includedParticipantCount, 1);
      assert.equal(refreshed[0].unavailableParticipantCount, 1);
      await call("GET", calculationPath, { sessionId: group.id, calculationId, status: 404 });
      await call("POST", refreshPath, { ...baseOptions, body: { recommendations: [] }, status: 400 });

      const publish = new PublishRoutedMeetupResultsUseCase(new MeetupSessionWorkflow());
      const routing = { status: "AVAILABLE" as const, participantCount: 1,
        journeysByPlace: new Map(placeIds.map((id, index) =>
          [id, [{ durationSeconds: 100 + index, distanceMeters: 400 + index }]])) };
      assert.equal(await publish.execute({ sessionId, calculationId, routing }), false);
      await prisma.meetup_calculations.update({ where: { id: calculationId }, data: { calculation_status: "CALCULATING" } });
      assert.equal((await call("GET", resultPath, baseOptions)).status, "CALCULATING");
      assert.equal(await publish.execute({ sessionId, calculationId, routing }), true);
      assert.equal(await publish.execute({ sessionId, calculationId, routing }), true);
      const ready = await call("GET", calculationPath, { ...baseOptions, calculationId });
      assert.equal(ready.status, "PARTIAL");
      assert.equal(ready.isPartial, true);
      assert.equal(ready.calculation.inputVersion, ready.inputVersion);
      assert.ok(ready.calculation.calculatedAt && ready.calculation.expiresAt);
      assert.deepEqual(ready.recommendations.map((r: { rank: number }) => r.rank), [1, 2, 3, 4, 5]);
      assert.deepEqual(ready.recommendations.map((r: { placeId: string }) => r.placeId), placeIds.slice(0, 5));
      const recommendation = ready.recommendations[0];
      assert.equal(recommendation.place.name, "Fixture venue 0");
      assert.equal(recommendation.averageRating, 4.5);
      assert.equal(recommendation.ratingCount, 2);
      assert.equal(recommendation.budgetLevel, "AFFORDABLE");
      assert.deepEqual(recommendation.explanationCodes, ["MATCHES_BUDGET"]);
      const independentEvent = {
        ...quickRequest, create_request_key: randomUUID(), group_id: null, occasion: "birthday",
        guest_phones: [phones[1]], guest_phones_whatsapp_opt_in: true,
      };
      await create({ ...independentEvent, scheduled_at: null }, 400);
      await create({ ...independentEvent, guest_phones_whatsapp_opt_in: false }, 400);
      const event = await create(independentEvent);
      assert.equal(event.status, "confirmed");
      assert.equal(event.type, "special_event");
      assert.equal(event.location_place_id, placeId);
      assert.equal(event.location_name, recommendation.place.name);
      assert.equal(event.location_latitude, location.latitude);
      assert.equal(event.location_longitude, location.longitude);
      assert.equal(event.location_address, null);
      assert.doesNotMatch(JSON.stringify(event), /smart_meetup_selection|input_fingerprint|30\.14682|31\.21846/);

      const origin = await prisma.saved_locations.create({ data: {
        user_id: member, ...privateOrigin, name: "Private starting point", location_type: "home",
      } });
      await prisma.default_starting_locations.create({ data: { user_id: member, saved_location_id: origin.id } });
      await prisma.user_location_privacy.create({ data: {
        user_id: member, automatic_meetup_location_usage_enabled: true,
        location_usage_consent_at: new Date(), consent_policy_version: locationUsagePolicyVersion,
      } });
      const groupResult = await call("POST", refreshPath, { sessionId: group.id });
      const groupCalculation = groupResult.calculation.id as string;
      await prisma.meetup_calculations.update({ where: { id: groupCalculation }, data: { calculation_status: "QUEUED" } });
      assert.equal(await publish.execute({ sessionId: group.id, calculationId: groupCalculation, routing }), true);
      const groupFixedRequest = {
        ...fixedRequest, create_request_key: randomUUID(),
        smart_meetup_selection: selection(group.id, groupCalculation, [placeId]),
      };
      await create(groupFixedRequest, 403, "outsider");
      await create({ ...groupFixedRequest, group_id: null, occasion: "birthday" }, 403);
      const fixed = await create(groupFixedRequest, 201, "member");
      assert.equal(fixed.location_place_id, placeId);
      assert.equal(fixed.status, "confirmed");
      assert.equal(fixed.location_latitude, location.latitude);
      const order = [placeIds[1], placeIds[0]];
      const groupVoting = {
        ...outingRequest, create_request_key: randomUUID(),
        smart_meetup_selection: selection(group.id, groupCalculation, order),
        location_latitude: privateOrigin.latitude, location_longitude: privateOrigin.longitude,
        initial_vote_options: order.map(place_id => ({
          place_id, label: "Untrusted option", ...privateOrigin,
        })),
      };
      await create({ ...groupVoting, create_request_key: undefined }, 400);
      await create({ ...groupVoting, vote_deadline_hours: undefined }, 400);
      await create({ ...groupVoting, occasion: "birthday", location_name: "Venue" }, 400);
      await create({ ...groupVoting, smart_meetup_selection: selection(group.id, groupCalculation, [placeId, placeId]) }, 400);
      await create({ ...groupVoting, initial_vote_options: [groupVoting.initial_vote_options[0]] }, 400);
      const fabricated = placeIds[7];
      await create({
        ...groupVoting, smart_meetup_selection: selection(group.id, groupCalculation, [placeId, fabricated]),
        initial_vote_options: [groupVoting.initial_vote_options[1], { label: "Other venue", place_id: fabricated }],
      }, 400);
      const voting = await Promise.all([create(groupVoting), create(groupVoting)]);
      assert.equal(voting[0].id, voting[1].id);
      assert.equal(voting[0].status, "voting");
      assert.equal(voting[0].location_latitude, null);
      assert.equal(voting[0].location_longitude, null);
      const votePath = outingPath + "/{id}/vote-options";
      const options = await call("GET", votePath, { outingId: voting[0].id });
      assert.deepEqual(options.map((option: { place_id: string }) => option.place_id), order);
      assert.deepEqual(options.map((option: { latitude: number }) => option.latitude), [location.latitude, location.latitude]);
      assert.deepEqual(options.map((option: { label: string }) => option.label), ["Fixture venue 1", "Fixture venue 0"]);
      assert.equal(await prisma.outing_attendance.count({ where: { outing_id: voting[0].id, user_id: owner, status: "going" } }), 1);
      const five = await create({
        ...groupVoting, create_request_key: randomUUID(),
        smart_meetup_selection: selection(group.id, groupCalculation, placeIds.slice(0, 5)),
        initial_vote_options: placeIds.slice(0, 5).map(place_id => ({ label: "Venue", place_id })),
      });
      assert.equal((await call("GET", votePath, { outingId: five.id })).length, 5);
      assert.equal((await create({ ...fixedRequest, create_request_key: randomUUID() })).status, "confirmed");
      assert.doesNotMatch(JSON.stringify(ready.calculation), /fingerprint|digest|participant_id/i);
      for (const row of ready.recommendations) {
        assert.deepEqual(Object.keys(row).sort(),
          ["averageRating", "budgetLevel", "explanationCodes", "place", "placeId", "rank", "ratingCount"]);
        assert.doesNotMatch(JSON.stringify(row.place), /source_id|source_type|participant|journey|duration|distance/i);
      }
      assert.equal(await prisma.meetup_recommendations.findFirst({ where: { calculation_id: calculationId, rank: 1 } })
        .then(row => row?.total_duration_seconds), 100);
      await assert.rejects(prisma.meetup_recommendations.create({ data: {
        calculation_id: calculationId, place_id: otherPlaces[4]!, rank: 6,
      } }));

      await prisma.places.update({ where: { id: placeId }, data: { is_active: false } });
      assert.equal((await create({ ...groupVoting, create_request_key: randomUUID() }, 409)).code, "stale_meetup_result");
      assert.equal((await create(groupVoting)).id, voting[0].id);
      await call("POST", refreshPath, { sessionId: group.id });
      assert.deepEqual(await call("GET", votePath, { outingId: voting[0].id }), options);
      await prisma.meetup_sessions.delete({ where: { id: group.id } });
      assert.equal((await create({ ...groupVoting, create_request_key: randomUUID() }, 404)).code, "stale_meetup_result");
      assert.equal((await call("GET", outingPath + "/{id}", { outingId: voting[0].id })).id, voting[0].id);
      const catalogStale = await call("GET", resultPath, baseOptions);
      assert.equal(catalogStale.status, "STALE");
      assert.deepEqual(catalogStale.recommendations, []);
      const next = await call("POST", refreshPath, baseOptions);
      assert.notEqual(next.calculation.id, calculationId);
      assert.equal(next.inputVersion, ready.inputVersion);
      assert.equal(next.status, "ROUTING_UNAVAILABLE");

      const replacementId = next.calculation.id as string;
      await prisma.meetup_calculations.update({ where: { id: replacementId }, data: { calculation_status: "QUEUED" } });
      assert.equal(await publish.execute({ sessionId, calculationId: replacementId, routing }), true);
      await fetch(base + sessionPath.replace("{sessionId}", sessionId) + "/participants/" + participantId, {
        method: "PATCH", headers: { authorization: "Bearer owner", "content-type": "application/json" },
        body: JSON.stringify({ transportation_mode: "WALKING" }),
      }).then(response => assert.equal(response.status, 200));
      const changed = await call("GET", calculationPath, { ...baseOptions, calculationId: replacementId });
      assert.equal(changed.status, "STALE");
      assert.ok(changed.inputVersion > changed.calculation.inputVersion);
      assert.deepEqual(changed.recommendations, []);
      assert.equal(await publish.execute({ sessionId, calculationId: replacementId, routing }), false);
      const current = await call("POST", refreshPath, baseOptions);
      const currentId = current.calculation.id as string;
      await prisma.meetup_calculations.update({ where: { id: currentId }, data: { calculation_status: "CALCULATING" } });
      assert.equal(await publish.execute({ sessionId, calculationId: currentId,
        routing: { ...routing, journeysByPlace: new Map([[placeIds[7]!, routing.journeysByPlace.get(placeId)!]]) } }), true);
      const empty = await call("GET", resultPath, baseOptions);
      assert.equal(empty.status, "NO_MATCHING_VENUES");
      assert.deepEqual(empty.recommendations, []);
      await prisma.meetup_calculations.update({ where: { id: currentId }, data: {
        calculated_at: new Date(1), expires_at: new Date(2),
      } });
      assert.equal((await call("GET", calculationPath, { ...baseOptions, calculationId: currentId })).status, "STALE");
      await call("DELETE", sessionPath, baseOptions);
      await call("POST", refreshPath, { ...baseOptions, status: 409 });
    });
  } finally {
    await prisma.meetup_sessions.deleteMany({ where: { created_by_user_id: { in: Object.values(users) } } });
    await prisma.outings.deleteMany({ where: { created_by: { in: Object.values(users) } } });
    await prisma.place_reviews.deleteMany({ where: { place_id: { in: placeIds } } });
    await prisma.places.deleteMany({ where: { id: { in: placeIds } } });
    await prisma.groups.deleteMany({ where: { id: groupId } });
    await prisma.users.deleteMany({ where: { id: { in: Object.values(users) } } });
    await deleteApp(firebase);
  }
});
