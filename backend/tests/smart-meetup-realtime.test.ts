import assert from "node:assert/strict";
import { randomInt, randomUUID } from "node:crypto";
import { once } from "node:events";
import { test } from "node:test";
import { deleteApp, initializeApp } from "firebase-admin/app";
import { getAuth } from "firebase-admin/auth";
import { io as connect } from "socket.io-client";
import app from "../src/app.js";
import { prisma } from "../src/config/database.js";
import { attachRealtime } from "../src/realtime/socket-server.js";
import { bindChatEmitter } from "../src/realtime/chat-emitter.js";
import { meetupRealtimeRoom } from "../src/realtime/rooms.js";
import { MeetupEventPublisher } from "../src/services/meetups/meetup-event-publisher.js";
import { meetupOptimizationPolicyVersion } from "../src/types/meetups/meetup-result.js";
import { locationUsagePolicyVersion } from "../src/types/users/location-privacy.types.js";
import { isolatedDatabase } from "./support/isolated-database.js";
import { responseAssertion, withApi, type OpenApi } from "./support/http-fixture.js";

test("committed Meetup hints use current socket authorization and Swagger returns authoritative versions",
  { skip: !isolatedDatabase, timeout: 30_000 }, async t => {
  const ids = { owner: randomUUID(), member: randomUUID(), outsider: randomUUID() };
  type Identity = keyof typeof ids;
  const groupId = randomUUID();
  const placeId = randomUUID();
  const unrelatedPlace = randomUUID();
  const sessions: string[] = [];
  const firebase = initializeApp({ projectId: "demo-yalla-meetup-realtime" });
  t.mock.method(getAuth(firebase), "verifyIdToken", async (token: string) => {
    const uid = ids[token as Identity];
    if (typeof uid !== "string") throw new Error("Bad test token");
    return { uid, firebase: { sign_in_provider: "custom" } };
  });

  try {
    await prisma.users.createMany({ data: Object.entries(ids).map(([name, id], i) => ({
      id, name, phone: `+201${i}${randomInt(10000000, 99999999)}`,
    })) });
    await prisma.groups.create({ data: { id: groupId, name: "Realtime fixture", created_by: ids.owner } });
    await prisma.group_members.create({ data: { group_id: groupId, user_id: ids.owner, role: "owner" } });
    await prisma.places.createMany({ data: [placeId, unrelatedPlace].map(id => ({ id, name: "Fixture venue" })) });
    const point = await prisma.saved_locations.create({ data: {
      user_id: ids.member, name: "Private reference", address: "Private address",
      location_type: "home", latitude: 30.0123, longitude: 31.0456,
    } });
    const unusedPoint = await prisma.saved_locations.create({ data: {
      user_id: ids.member, name: "Unused location", location_type: "work", latitude: 29, longitude: 31,
    } });

    await withApi(app, async (origin, http) => {
      const socketServer = attachRealtime(http);
      const clients: ReturnType<typeof connect>[] = [];
      const client = (who?: Identity) => {
        const socket = connect(origin, {
          autoConnect: false, reconnection: false, forceNew: true, transports: ["websocket"],
          auth: who ? { token: who } : {},
        });
        clients.push(socket);
        return socket;
      };
      try {
        const spec = await (await fetch(origin + "/api-docs/openapi.json")).json() as OpenApi;
        const call = async (method: string, path: string, who: Identity, options: {
          params?: Record<string, string>; body?: unknown; status?: number;
        } = {}) => {
          const operation = spec.paths[path]?.[method.toLowerCase()];
          assert.ok(operation, `Undocumented operation ${method} ${path}`);
          const url = path.replace(/\{(\w+)\}/g, (_match, id) => options.params?.[id] ?? "");
          const response = await fetch(origin + url, {
            method, headers: { authorization: "Bearer " + who, "content-type": "application/json" },
            body: options.body === undefined ? undefined : JSON.stringify(options.body),
          });
          const json = await response.json();
          assert.equal(response.status, options.status ?? 200, `${method} ${path}`);
          responseAssertion(spec, operation, response.status, "application/json", json);
          return json.data;
        };
        const sessionPath = "/api/smart-meetups/{sessionId}";
        const sessionId = (await call("POST", "/api/groups/{groupId}/smart-meetup", "owner", { params: { groupId } })).id as string;
        const quickId = (await call("POST", "/api/smart-meetups/standalone", "owner")).id as string;
        sessions.push(sessionId, quickId);
        const params = { sessionId };

        const anonymous = client();
        const rejected = new Promise<Error>(resolve => anonymous.once("connect_error", resolve));
        anonymous.connect();
        assert.match((await rejected).message, /UNAUTHORIZED/);
        const owner = client("owner"), member = client("member"), outsider = client("outsider");
        await Promise.all([owner, member, outsider].map(async socket => {
          const connected = once(socket, "connect");
          socket.connect();
          await connected;
        }));
        const ack = (socket: typeof owner, action = "join", body = params) =>
          socket.timeout(2000).emitWithAck("meetup:" + action, body);
        assert.deepEqual(await ack(outsider), { ok: false, error: "FORBIDDEN" });
        assert.deepEqual(await ack(member, "join", { sessionId: quickId }), { ok: false, error: "FORBIDDEN" });
        assert.deepEqual(await ack(outsider, "join", { sessionId: meetupRealtimeRoom(sessionId) }),
          { ok: false, error: "INVALID_SESSION_ID" });
        assert.deepEqual(await ack(owner), { ok: true, inputVersion: 1 });
        assert.equal((await ack(owner, "join", { sessionId: quickId })).ok, true);
        assert.equal((await ack(owner, "leave", { sessionId: quickId })).ok, true);
        assert.equal(socketServer.sockets.sockets.get(owner.id!)?.rooms.has(meetupRealtimeRoom(quickId)), false);
        assert.equal(socketServer.sockets.sockets.get(owner.id!)?.rooms.has("user:" + ids.owner), true);

        const publisher = new MeetupEventPublisher();
        const events = () => prisma.notification_events.findMany({
          where: { channel: "realtime", payload: { path: ["sessionId"], equals: sessionId } },
          orderBy: { created_at: "desc" },
        });
        async function send(changeType: string, version: number, attempt?: number) {
          const expected = { sessionId, inputVersion: version, changeType,
            ...(attempt !== undefined && { calculationAttempt: attempt }) };
          const rows = (await events()).filter(row => {
            const payload = row.payload as typeof expected;
            return payload.changeType === changeType && payload.inputVersion === version &&
              payload.calculationAttempt === attempt;
          });
          assert.equal(rows.length, 1);
          assert.deepEqual(rows[0].payload, expected);
          const received = once(owner, "smart_meetup:" + changeType.toLowerCase());
          const result = await publisher.send({ eventId: rows[0].id, channel: "realtime",
            recipientPhone: null, recipientUserId: null, payload: expected });
          assert.equal(result.status, "sent");
          assert.deepEqual((await received)[0], expected);
        }

        await prisma.group_members.create({ data: { group_id: groupId, user_id: ids.member } });
        await send("READINESS_CHANGED", 2);
        assert.deepEqual(await ack(member), { ok: true, inputVersion: 2 });
        assert.equal((await call("GET", sessionPath + "/readiness", "owner", { params })).intended, 2);

        await call("PUT", "/api/users/me/location-consent", "member", {
          body: { consent_policy_version: locationUsagePolicyVersion },
        });
        await call("PUT", "/api/users/me/default-starting-location", "member", {
          body: { source: "saved_location", referenceId: point.id },
        });
        const ready = await call("GET", sessionPath, "owner", { params });
        await send("READINESS_CHANGED", ready.input_version);
        assert.equal(ready.readiness.usable, 1);
        assert.doesNotMatch(JSON.stringify(ready), /Private reference|Private address|30\.0123|31\.0456/);
        assert.equal((await call("GET", sessionPath, "owner", { params: { sessionId: quickId } })).input_version, 1);
        await prisma.saved_locations.update({ where: { id: unusedPoint.id }, data: { name: "Unused rename" } });
        assert.equal((await call("GET", sessionPath, "owner", { params })).input_version, ready.input_version);

        const beforeRollback = (await events()).length;
        await assert.rejects(prisma.$transaction(async tx => {
          await tx.saved_locations.update({ where: { id: point.id }, data: { name: "Rollback" } });
          throw new Error("Fixture rollback");
        }), /Fixture rollback/);
        assert.equal((await events()).length, beforeRollback);
        assert.equal((await call("GET", sessionPath, "owner", { params })).input_version, ready.input_version);
        await assert.rejects(prisma.notification_events.update({
          where: { id: (await events())[0].id },
          data: { payload: { sessionId, inputVersion: ready.input_version, changeType: "READINESS_CHANGED", privateField: true } },
        }));

        const preferences = await call("PUT", sessionPath + "/preferences", "owner", { params,
          body: { ...ready.preferences, minimumRating: 4 } });
        await send("PREFERENCES_CHANGED", preferences.input_version);
        assert.equal((await events()).filter(row =>
          (row.payload as { inputVersion: number }).inputVersion === preferences.input_version).length, 1);

        // Seed a terminal attempt with catalog dependency only. No routing adapter runs.
        const planning = await prisma.meetup_sessions.findUniqueOrThrow({ where: { id: sessionId } });
        const calculation = await prisma.meetup_calculations.create({ data: {
          meetup_session_id: sessionId, input_version: planning.input_version, attempt: 1,
          input_fingerprint: planning.input_digest!, optimization_policy_version: meetupOptimizationPolicyVersion,
          calculation_status: "NO_MATCHING_VENUES", calculated_at: new Date(),
          expires_at: new Date(Date.now() + 5 * 60_000), candidate_place_ids: [placeId],
          intended_participant_count: 2, included_participant_count: 1, unavailable_participant_count: 1, is_partial: true,
        } });
        await send("CALCULATION_COMPLETED", planning.input_version, 1);
        const resultPath = sessionPath + "/results";
        const result = await call("GET", resultPath, "member", { params });
        assert.equal(result.calculation.attempt, 1);
        assert.equal(result.sessionStatus, "ACTIVE");
        await prisma.places.update({ where: { id: unrelatedPlace }, data: { status: "permanently_closed", is_active: false } });
        assert.equal((await prisma.meetup_calculations.findUniqueOrThrow({ where: { id: calculation.id } })).calculation_status,
          "NO_MATCHING_VENUES");
        await prisma.places.update({ where: { id: placeId }, data: { status: "permanently_closed", is_active: false } });
        await send("RESULTS_INVALIDATED", planning.input_version, 1);
        assert.equal((await call("GET", resultPath, "owner", { params })).status, "STALE");

        await call("DELETE", "/api/users/me/location-consent", "member");
        const withdrawal = await call("GET", sessionPath, "owner", { params });
        await send("READINESS_CHANGED", withdrawal.input_version);
        assert.equal(withdrawal.readiness.usable, 0);
        assert.equal(socketServer.sockets.sockets.get(member.id!)?.rooms.has(meetupRealtimeRoom(sessionId)), true);
        const revocation = once(member, "smart_meetup:subscription_revoked");
        let removedMemberHints = 0;
        member.on("smart_meetup:readiness_changed", (event: { inputVersion: number }) => {
          if (event.inputVersion > withdrawal.input_version) removedMemberHints++;
        });
        await prisma.group_members.delete({ where: { group_id_user_id: { group_id: groupId, user_id: ids.member } } });
        await send("READINESS_CHANGED", withdrawal.input_version + 1);
        assert.deepEqual((await revocation)[0], { sessionId });
        assert.equal(removedMemberHints, 0);
        assert.equal(socketServer.sockets.sockets.get(member.id!)?.rooms.has(meetupRealtimeRoom(sessionId)), false);
        assert.deepEqual(await ack(member), { ok: false, error: "FORBIDDEN" });
        await call("GET", sessionPath, "member", { params, status: 403 });
        assert.equal((await call("GET", sessionPath + "/readiness", "owner", { params })).intended, 1);

        const reconnected = once(owner, "connect");
        owner.disconnect().connect();
        await reconnected;
        assert.deepEqual(await ack(owner), { ok: true, inputVersion: withdrawal.input_version + 1 });
        await prisma.meetup_sessions.update({ where: { id: sessionId }, data: { expires_at: new Date(0) } });
        const expired = await call("GET", sessionPath, "owner", { params });
        assert.equal(expired.status, "EXPIRED");
        await send("SESSION_EXPIRED", expired.input_version);
        assert.equal((await call("GET", resultPath, "owner", { params })).sessionStatus, "EXPIRED");
        assert.deepEqual(await ack(owner), { ok: false, error: "CLOSED" });
      } finally {
        clients.forEach(socket => socket.close());
        await socketServer.close();
        bindChatEmitter(null);
      }
    });
  } finally {
    await prisma.groups.deleteMany({ where: { id: groupId } });
    await prisma.users.deleteMany({ where: { id: { in: Object.values(ids) } } });
    await prisma.places.deleteMany({ where: { id: { in: [placeId, unrelatedPlace] } } });
    for (const sessionId of sessions) {
      await prisma.notification_events.deleteMany({ where: { channel: "realtime", payload: { path: ["sessionId"], equals: sessionId } } });
    }
    await deleteApp(firebase);
  }
});
