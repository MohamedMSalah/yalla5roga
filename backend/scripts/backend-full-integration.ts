import "dotenv/config";
import assert from "node:assert/strict";
import { randomUUID } from "node:crypto";
import { once } from "node:events";
import { getApp } from "firebase-admin/app";
import { io as connectSocket, type Socket } from "socket.io-client";
import { attachRealtime } from "../src/realtime/index.js";
import app from "../src/app.js";
import { prisma } from "../src/config/database.js";
import { hasAutomaticWhatsApp } from "../src/config/notifications.js";
import { getFirebaseAuth } from "../src/config/firebase.js";
import { swaggerSpec } from "../src/config/swagger.js";

if (process.env.NODE_ENV !== "development" || process.env.FIREBASE_AUTH_EMULATOR_HOST) {
  throw new Error("Run only against the real development Firebase and Neon configuration");
}

const auth = getFirebaseAuth();
const firebaseApp = getApp();
const marker = "audit-" + randomUUID().slice(0, 8);
const password = randomUUID();
const registered = new Set<string>();
const placeIds = new Set<string>();
const statuses: Record<string, { ok: number[]; failed: number[]; auth: number[]; ms: number[] }> = {};
const cases: Record<string, string> = {};
const contractGaps = new Set<string>();
type Schema = {
  $ref?: string; nullable?: boolean; type?: string; enum?: unknown[];
  required?: string[]; properties?: Record<string, Schema>; items?: Schema;
  allOf?: Schema[]; oneOf?: Schema[];
};
type DocumentedResponse = {
  $ref?: string;
  content?: Record<string, { schema: Schema }>;
};
const server = app.listen(0, "127.0.0.1");
const realtime = attachRealtime(server);
await once(server, "listening");
const address = server.address();
assert.ok(address && typeof address !== "string");
const base = "http://127.0.0.1:" + address.port;
type Operation = { security?: unknown[]; responses: Record<string, DocumentedResponse> };
const { paths } = swaggerSpec as { paths: Record<string, Record<string, Operation>> };
const operations = Object.entries(paths).flatMap(([path, methods]) =>
  Object.entries(methods).map(([method, op]) => ({
    key: method.toUpperCase() + " " + path, method: method.toUpperCase(), path,
    protected: op.security?.length !== 0, responses: op.responses,
  })),
);

const operationByKey = new Map(operations.map(operation => [operation.key, operation]));

function resolveRef<T>(ref: string): T {
  return ref.slice(2).split("/").reduce<unknown>((target, part) =>
    (target as Record<string, unknown>)[part], swaggerSpec) as T;
}

function schemaIssue(schema: Schema, value: unknown, path = "$"): string | undefined {
  if (schema.$ref) return schemaIssue(resolveRef<Schema>(schema.$ref), value, path);
  if (value === null && schema.nullable) return;
  if (schema.enum && !schema.enum.includes(value)) return path + " enum";
  if (schema.oneOf && schema.oneOf.filter(choice => !schemaIssue(choice, value, path)).length !== 1) {
    return path + " oneOf";
  }
  for (const clause of schema.allOf ?? []) {
    const issue = schemaIssue(clause, value, path);
    if (issue) return issue;
  }
  if (schema.type === "array") {
    if (!Array.isArray(value)) return path + " array";
    for (const item of value) {
      const issue = schema.items && schemaIssue(schema.items, item, path + "[]");
      if (issue) return issue;
    }
  } else if (schema.type === "object") {
    if (!value || typeof value !== "object" || Array.isArray(value)) return path + " object";
    const fields = value as Record<string, unknown>;
    for (const field of schema.required ?? []) {
      if (!(field in fields)) return path + "." + field + " missing";
    }
    for (const [field, child] of Object.entries(schema.properties ?? {})) {
      if (!(field in fields)) continue;
      const issue = schemaIssue(child, fields[field], path + "." + field);
      if (issue) return issue;
    }
  } else if (schema.type === "integer") {
    if (!Number.isInteger(value)) return path + " integer";
  } else if (schema.type && typeof value !== schema.type) {
    return path + " " + schema.type;
  }
}

async function request(key: string, expected: number | number[], options: {
  token?: string; body?: unknown; params?: Record<string, string>; query?: string;
  authentication?: boolean; invalidJson?: boolean;
} = {}) {
  const [method, route] = key.split(" ");
  const path = route.replace(/\{(\w+)\}/g, (_, field) =>
    encodeURIComponent(options.params?.[field] ?? randomUUID()),
  );
  const start = performance.now();
  const res = await fetch(base + path + (options.query ?? ""), {
    method,
    headers: {
      ...(options.token ? { Authorization: "Bearer " + options.token } : {}),
      ...(options.body !== undefined || options.invalidJson ? { "Content-Type": "application/json" } : {}),
    },
    body: options.invalidJson ? "{" : options.body === undefined ? undefined : JSON.stringify(options.body),
    signal: AbortSignal.timeout(25000),
  });
  const elapsed = Math.round(performance.now() - start);
  const result = (statuses[key] ??= { ok: [], failed: [], auth: [], ms: [] });
  const json = await res.json().catch(() => null);
  const match = [expected].flat().includes(res.status) &&
    json?.success === (res.status < 400) &&
    (res.status < 400 || typeof json.message === "string");
  (match ? options.authentication ? result.auth : result.ok : result.failed).push(res.status);
  result.ms.push(elapsed);
  const operation = operationByKey.get(key);
  if (operation && match) {
    let contract = operation.responses[String(res.status)];
    if (contract?.$ref) contract = resolveRef<DocumentedResponse>(contract.$ref);
    const schema = contract?.content?.["application/json"]?.schema;
    const gap = !contract ? "status missing" : schema && schemaIssue(schema, json);
    if (gap) contractGaps.add(key + " " + res.status + " " + gap);
  }
  assert.ok(match, key + " expected " + expected + " observed " + res.status);
  return { status: res.status, data: json.data, json };
}

async function check(label: string, run: () => Promise<unknown>) {
  try {
    await run();
    cases[label] = "PASS";
    console.log("AUDIT_CASE", label, "PASS");
  } catch (error) {
    const detail = error instanceof assert.AssertionError ? error.message.split("\n")[0] : "Unexpected dependency or request error";
    cases[label] = "FAIL " + detail;
    console.log("AUDIT_CASE", label, cases[label]);
  }
}

async function authRequest(operation: string, body: object) {
  const response = await fetch("https://identitytoolkit.googleapis.com/v1/accounts:" + operation +
    "?key=" + encodeURIComponent(process.env.FIREBASE_API_KEY ?? ""), {
    method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify(body),
    signal: AbortSignal.timeout(20000),
  });
  const result = await response.json();
  assert.ok(response.ok, "Firebase " + operation + " returned " + response.status + " (" +
    String(result.error?.message ?? "").split(" : ")[0].replace(/[^A-Z_]/g, "") + ")");
  return result;
}

async function otp(phone: string, code: string) {
  const verification = await authRequest("sendVerificationCode", { phoneNumber: phone });
  const result = await authRequest("signInWithPhoneNumber", { sessionInfo: verification.sessionInfo, code });
  assert.equal(result.isNewUser, true, "OTP must create a new isolated identity");
  registered.add(result.localId);
  const decoded = await auth.verifyIdToken(result.idToken, true);
  assert.equal(decoded.phone_number, phone);
  assert.equal(decoded.firebase.sign_in_provider, "phone");
  assert.equal(decoded.uid, result.localId);
  return { uid: decoded.uid, token: result.idToken };
}

function socketEvent(socket: Socket, event: string, signal: AbortSignal): Promise<unknown> {
  signal.throwIfAborted();
  return new Promise((resolve, reject) => {
    function received(value: unknown) {
      signal.removeEventListener("abort", cancelled);
      resolve(value);
    }
    function cancelled() {
      socket.off(event, received);
      reject(signal.reason);
    }
    signal.addEventListener("abort", cancelled, { once: true });
    socket.once(event, received);
  });
}

const signup = (phone: string, proof: string) =>
  request("POST /api/auth/signup", 201, { body: { phone, name: marker, password, phoneVerificationToken: proof } });
const login = (phone: string) => request("POST /api/auth/login", 200, { body: { phone, password } });
const getFeature = (key: string, token: string, params: Record<string, string>) =>
  request(key, 200, { token, params });

async function exerciseGroupOutingFeatures(input: {
  groupId: string; owner: string; ownerId: string;
  future: string; memberId: string; outsider: string; renewSession: () => Promise<string>;
}) {
  const { groupId, owner, ownerId, future, memberId, outsider, renewSession } = input;
  await check("three overlapping group outings, RSVP, place vote and confirmed-venue arrivals", async () => {
    const start = new Date(Date.now() - 60_000);
    const create = async (label: string, extras: object) => (await request("POST /api/outings", 201, {
      token: owner, body: { group_id: groupId, title: marker + "-" + label,
        scheduled_at: start, vote_deadline_hours: 2, ...extras },
    })).data;
    const venue = { location_name: "Fixture venue", location_latitude: 30.05, location_longitude: 31.24 };
    const [poll, fixed, past] = await Promise.all([
      create("poll", { initial_vote_options: [
        { label: "Place A", latitude: 30.10, longitude: 31.24 },
        { label: "Place B", latitude: 30.20, longitude: 31.24 },
        { label: "Place C", latitude: 30.05, longitude: 31.24 },
      ] }),
      create("fixed", { ...venue, status: "confirmed" }),
      create("past", { ...venue, status: "past" }),
    ]);
    assert.equal(new Set([poll.id, fixed.id, past.id]).size, 3);
    assert.deepEqual([poll, fixed, past].map(row => new Date(row.scheduled_at).getTime()), [start.getTime(), start.getTime(), start.getTime()]);
    assert.deepEqual([poll.status, fixed.status, past.status], ["voting", "confirmed", "past"]);
    const groupList = await request("GET /api/outings", 200, { token: future, query: "?groupId=" + groupId });
    for (const row of [poll, fixed, past]) assert.ok(groupList.data.some((item: { id: string }) => item.id === row.id));
    const params = { id: poll.id, outingId: poll.id };
    await request("PATCH /api/outings/{id}", 200, {
      token: owner, params, body: { title: marker + "-edit" },
    });
    assert.equal((await getFeature("GET /api/outings/{id}", future, { id: fixed.id })).data.title, fixed.title);
    assert.equal((await getFeature("GET /api/outings/{id}", future, { id: past.id })).data.status, "past");
    const rsvp = (status: string, token = future) =>
      request("PUT /api/outings/{id}/attendance", 200, { token, params, body: { status } });
    await request("GET /api/outings/{id}/attendance", 403, { token: outsider, params });
    for (const response of ["going", "maybe", "not_going"]) {
      const saved = await rsvp(response);
      assert.equal(saved.json.my_response, response);
      assert.equal(saved.json.summary[response], response === "going" ? 2 : 1);
      assert.equal(saved.json.items.length, 2);
      assert.equal((await rsvp(response)).data.updated_at, saved.data.updated_at);
    }
    const newSession = await renewSession();
    assert.equal((await getFeature("GET /api/outings/{id}/attendance", newSession, params)).json.my_response, "not_going");
    assert.equal((await getFeature("GET /api/outings/{id}/attendance", newSession, { id: fixed.id })).json.my_response, null);
    const voting = () => getFeature("GET /api/outings/{id}/voting-state", newSession, params);
    const [placeA, placeB, placeC] = (await voting()).data.options;
    assert.deepEqual([placeA.label, placeB.label, placeC.label], ["Place A", "Place B", "Place C"]);
    for (const [selected, counts] of [[placeA, [1, 0, 0]], [placeB, [0, 1, 0]]] as const) {
      await request("POST /api/outings/{id}/votes", 201, { token: newSession, params, body: { option_id: selected.id } });
      const state = (await voting()).data;
      assert.equal(state.my_option_id, selected.id);
      assert.deepEqual(state.options.map((row: { vote_count: number }) => row.vote_count), counts);
    }
    assert.equal(await prisma.outing_votes.count({ where: { outing_id: poll.id, user_id: memberId } }), 1);
    assert.equal(await prisma.outing_votes.count({ where: { outing_id: fixed.id } }), 0);

    const position = () => ({ latitude: 30.05, longitude: 31.24, accuracy: 10,
      captured_at: new Date().toISOString(), method: "gps" });
    const checkIn = (body: object, token = newSession, expected = 200, id = poll.id) =>
      request("PUT /api/outings/{id}/arrivals/self", expected, { token, params: { id }, body });
    assert.equal((await checkIn(position())).data.arrived, false);
    await checkIn(position(), outsider, 403);
    const confirm = (token: string, status: number) => request("PUT /api/outings/{id}/confirmed-venue", status,
      { token, params, body: { option_id: placeC.id } });
    await confirm(newSession, 403);
    assert.equal((await confirm(owner, 200)).data.winningOptionId, placeC.id);
    await confirm(owner, 200);
    assert.equal((await getFeature("GET /api/outings/{id}", owner, params)).data.location_latitude, 30.05);
    const roster = () => getFeature("GET /api/outings/{id}/arrivals", newSession, params);
    assert.deepEqual((await roster()).data.venue, { latitude: 30.05, longitude: 31.24 });
    await checkIn({ ...position(), user_id: ownerId }, newSession, 400);
    for (const invalid of [
      { latitude: 30.051 },
      { accuracy: 51 },
      { is_mocked: true },
      { captured_at: new Date(Date.now() - 45_000).toISOString() },
    ]) assert.equal((await checkIn({ ...position(), ...invalid }, owner)).data.arrived, false);
    assert.equal((await roster()).data.total_confirmed, 0, "Going alone must not mark the owner arrived");
    const observers = [owner, newSession].map(token => connectSocket(base, {
      auth: { token }, transports: ["websocket"], reconnection: false, autoConnect: false,
    }));
    try {
      const connections = observers.map(socket => socketEvent(socket, "connect", AbortSignal.timeout(20_000)));
      observers.forEach(socket => socket.connect());
      await Promise.all(connections);
      for (const token of [newSession, owner]) {
        const events = observers.map(socket => socketEvent(socket, "outing:arrival_changed", AbortSignal.timeout(20_000)));
        assert.equal((await checkIn(position(), token)).data.arrived, true);
        assert.deepEqual(await Promise.all(events), [{ outing_id: poll.id }, { outing_id: poll.id }]);
      }
      assert.equal((await roster()).data.total_confirmed, 2);
      const before = await prisma.outing_arrivals.findUniqueOrThrow({
        where: { outing_id_user_id: { outing_id: poll.id, user_id: memberId } },
      });
      const checks = await Promise.all([checkIn(position()), checkIn({ ...position(), latitude: 30.20 })]);
      assert.ok(checks.every(result => result.data.arrived), "A persisted arrival survives leaving the venue");
      const after = await prisma.outing_arrivals.findMany({ where: { outing_id: poll.id, user_id: memberId } });
      assert.equal(after.length, 1);
      assert.equal(after[0].verification_method, "gps");
      assert.equal(after[0].verification_distance, 0);
      assert.equal(after[0].location_accuracy, 10);
      assert.equal(after[0].arrived_at.getTime(), before.arrived_at.getTime());
    } finally {
      observers.forEach(socket => socket.disconnect());
    }
    assert.equal(await prisma.outing_arrivals.count({ where: { outing_id: fixed.id } }), 0);

    const firstMessage = (await request("POST /api/outings/{outingId}/messages", 201, {
      token: newSession, params, body: { text: marker + " first", clientMessageId: randomUUID() },
    })).data;
    const recipient = connectSocket(base, {
      auth: { token: newSession }, transports: ["websocket"], reconnection: false, autoConnect: false,
    });
    const join = async () => {
      const connected = socketEvent(recipient, "connect", AbortSignal.timeout(10_000));
      recipient.connect();
      await connected;
      assert.equal((await recipient.timeout(5000).emitWithAck("outing:join", { outingId: poll.id })).ok, true);
    };
    let nextMessage;
    try {
      await join();
      const delivery = socketEvent(recipient, "outing:message", AbortSignal.timeout(10_000));
      const messageBody = { text: marker + " next", clientMessageId: randomUUID() };
      const send = () => request("POST /api/outings/{outingId}/messages", 201, {
        token: owner, params, body: messageBody,
      });
      nextMessage = (await send()).data;
      const delivered = await delivery as { id: string; sender: string };
      assert.equal(delivered.id, nextMessage.id);
      assert.equal(delivered.sender, nextMessage.sender);
      recipient.disconnect();
      assert.equal((await send()).data.id, nextMessage.id);
      await join();
      const recovered = await request("GET /api/outings/{outingId}/messages", 200, {
        token: newSession, params, query: "?limit=40",
      });
      assert.equal(recovered.data.filter((item: { id: string }) => item.id === nextMessage.id).length, 1);
    } finally {
      recipient.disconnect();
    }
    assert.equal(firstMessage.sender, (await prisma.users.findUniqueOrThrow({ where: { id: memberId } })).name);
    assert.equal(nextMessage.sender, (await prisma.users.findUniqueOrThrow({ where: { id: ownerId } })).name);
    const latest = await request("GET /api/outings/{outingId}/messages", 200, { token: owner, params, query: "?limit=1" });
    assert.equal(latest.data[0].id, nextMessage.id);
    const older = await request("GET /api/outings/{outingId}/messages", 200, {
      token: owner, params, query: "?limit=1&before=" + latest.json.next_cursor,
    });
    assert.equal(older.data[0].id, firstMessage.id);
    assert.equal(older.data[0].sender, firstMessage.sender);
    const messageQuery = "?messageId=" + firstMessage.id;
    const exact = await request("GET /api/outings/{outingId}/messages", 200, {
      token: owner, params, query: messageQuery,
    });
    assert.deepEqual(exact.data.map((item: { id: string }) => item.id), [firstMessage.id]);
    await request("GET /api/outings/{outingId}/messages", 404, {
      token: owner, params: { outingId: fixed.id }, query: messageQuery,
    });
    await request("GET /api/outings/{outingId}/messages", 403, {
      token: outsider, params, query: messageQuery,
    });
    const inbox = (await request("GET /api/notifications", 200, { token: owner })).data;
    const notice = inbox.find((row: { messageId?: string }) => row.messageId === firstMessage.id);
    assert.equal(notice?.eventType, "chat_message");
    assert.equal(notice.outing_id, poll.id);
    assert.equal(notice.is_read, false);
    const read = await request("PATCH /api/notifications/{id}/read", 200, {
      token: owner, params: { id: notice.id },
    });
    assert.equal(read.data.is_read, true);
    assert.equal(await prisma.chat_messages.count({ where: { outing_id: fixed.id } }), 0);
    await request("DELETE /api/groups/{id}/members/{userId}", 200, {
      token: owner, params: { id: groupId, userId: memberId },
    });
    await checkIn(position(), newSession, 403, fixed.id);
    assert.equal(await prisma.outing_arrivals.count({ where: { outing_id: fixed.id } }), 0);
  });
}

async function runCustomSessionFeatures() {
  const start = 100 + Math.floor(Math.random() * 90);
  const makeFixture = async (name: string, offset: number) => {
    const phone = "+12025550" + (start + offset);
    assert.equal(await prisma.users.count({ where: { phone } }), 0, "Fixture phone already in use");
    const uid = marker + "-" + name.toLowerCase();
    await auth.createUser({ uid, displayName: name });
    registered.add(uid);
    await prisma.users.create({ data: { id: uid, name, phone } });
    const renew = async (): Promise<string> => {
      const token = await auth.createCustomToken(uid);
      const session = await authRequest("signInWithCustomToken", { token, returnSecureToken: true });
      assert.equal((await auth.verifyIdToken(session.idToken)).uid, uid);
      return session.idToken;
    };
    return { uid, token: await renew(), renew };
  };
  const owner = await makeFixture("Mohamed", 0);
  const member = await makeFixture("Ahmed", 1);
  const outsider = await makeFixture("Outsider", 2);
  const group = (await request("POST /api/groups", 201, {
    token: owner.token, body: { name: marker },
  })).data;
  await prisma.group_members.create({ data: { group_id: group.id, user_id: member.uid } });
  await check("pending group phone association and duplicate protection on real Firebase and Neon", async () => {
    const phone = "+12025550" + (start + 3);
    assert.equal(await prisma.users.count({ where: { phone } }), 0);
    await assert.rejects(auth.getUserByPhoneNumber(phone), { code: "auth/user-not-found" });
    const invite = (status: number) => request("POST /api/groups/{id}/invitations", status, {
      token: owner.token, params: { id: group.id }, body: { phoneNumber: phone },
    });
    const first = await invite(201);
    assert.equal(first.data.notification_queued, false);
    assert.equal(first.data.whatsapp_url, null);
    assert.equal((await invite(409)).data.invitation_id, first.data.invitation_id);
    const association = await prisma.group_invitations.findUniqueOrThrow({ where: { id: first.data.invitation_id } });
    assert.equal(association.status, "pending");
    assert.equal(association.user_id, null);
    assert.equal(association.invited_phone, phone);
    assert.equal(await prisma.notification_events.count({ where: { invitation_id: association.id } }), 0);
  });
  await exerciseGroupOutingFeatures({
    groupId: group.id, owner: owner.token, ownerId: owner.uid,
    future: member.token, memberId: member.uid, outsider: outsider.token,
    renewSession: member.renew,
  });
}

let phones: string[] = [];
try {
  const docs = await fetch(base + "/api-docs/swagger-ui-init.js");
  assert.equal(docs.status, 200);
  assert.match(await docs.text(), /revokePendingGroupMembership/);
  await check("process and real Neon health", async () => {
    await request("GET /", 200);
    assert.equal((await request("GET /health", 200)).json.database, "connected");
  });
  await check("missing and invalid token across all protected operations", async () => {
    const rejected = await Promise.allSettled(operations.filter(op => op.protected).map(async op => {
      await request(op.key, 401, { body: ["POST", "PATCH", "PUT", "DELETE"].includes(op.method) ? {} : undefined, authentication: true });
      await request(op.key, 401, { token: "invalid-id-token", authentication: true });
    }));
    assert.equal(rejected.filter(result => result.status === "rejected").length, 0);
  });
  await check("malformed JSON and missing authentication fields", async () => {
    await request("POST /api/auth/login", 400, { invalidJson: true });
    await request("POST /api/auth/login", 400, { body: {} });
    await request("POST /api/auth/signup", 400, { body: {} });
  });

  if (process.argv.includes("--custom-session-features")) {
    await runCustomSessionFeatures();
  } else {
  const credential = await firebaseApp.options.credential!.getAccessToken();
  const configRes = await fetch("https://identitytoolkit.googleapis.com/admin/v2/projects/" +
    firebaseApp.options.projectId + "/config", {
    headers: { Authorization: "Bearer " + credential.access_token }, signal: AbortSignal.timeout(15000),
  });
  assert.equal(configRes.status, 200, "Read Firebase development test-number configuration");
  const config = await configRes.json();
  const available: [string, string][] = [];
  for (const [phone, code] of Object.entries<string>(config.signIn?.phoneNumber?.testPhoneNumbers ?? {})) {
    const unused = await auth.getUserByPhoneNumber(phone).then(() => false, error => {
      if (error.code !== "auth/user-not-found") throw error;
      return true;
    });
    if (unused && !(await prisma.users.count({ where: { phone } })) &&
        !(await prisma.group_invitations.count({ where: { invited_phone: phone } }))) {
      available.push([phone, code]);
    }
  }
  assert.ok(available.length >= 3, "BLOCKED: three clean configured Firebase test numbers are required");
  const [a, b, c] = available;
  phones = [a[0], b[0], c[0]];
  const ownerProof = await otp(...a);
  const ownerSession = (await signup(a[0], ownerProof.token)).data;
  const owner = ownerSession.idToken;
  assert.equal(ownerSession.uid, ownerProof.uid);
  assert.equal((await auth.verifyIdToken(owner)).uid, ownerProof.uid);
  const registeredProof = await otp(...b);
  const member = (await signup(b[0], registeredProof.token)).data.idToken;
  cases["Firebase Phone OTP and UID-consistent Neon signup"] = "PASS";
  const group = async () => (await request("POST /api/groups", 201, { token: owner, body: { name: marker } })).data.id as string;
  const groups = await Promise.all([group(), group(), group(), group(), group()]);
  const [first, second, third, revoked, race] = groups;
  const invite = (id: string, phoneNumber: string, token: string, expected: number | number[]) =>
    request("POST /api/groups/{id}/invitations", expected, { token, params: { id }, body: { phoneNumber } });
  const listGroups = (token: string) => request("GET /api/groups/cuser", 200, { token });
  const outingRequest = async (id: string, token = owner, expected = 201) => request("POST /api/outings", expected, {
    token, body: { title: marker, group_id: id, vote_deadline_hours: 2, initial_vote_options: [{ label: "A" }, { label: "B" }] },
  });
  await check("registered B becomes an active member immediately", async () => {
    assert.equal((await listGroups(member)).data.length, 0);
    const added = await Promise.all([invite(first, b[0], owner, [201, 409]), invite(first, b[0], owner, [201, 409])]);
    assert.deepEqual(added.map(row => row.status).sort(), [201, 409]);
    assert.equal(added.find(row => row.status === 201)?.data.member.user_id, registeredProof.uid);
    assert.equal(await prisma.group_members.count({ where: { group_id: first, user_id: registeredProof.uid } }), 1);
    const visible = (await listGroups(member)).data.find((row: { id: string }) => row.id === first);
    assert.equal(visible?.my_role, "member");
    await request("GET /api/groups/{id}", 200, { token: member, params: { id: first } });
    await request("GET /api/groups/{id}/members", 200, { token: member, params: { id: first } });
    await request("PATCH /api/groups/{id}", 403, { token: member, params: { id: first }, body: { bio: "Forbidden" } });
    await request("GET /api/groups", 403, { token: member, query: "?userId=" + ownerProof.uid });
    await request("GET /api/groups", 200, { token: member });
    await request("PATCH /api/groups/{id}", 200, { token: owner, params: { id: first }, body: { bio: marker } });
  });
  await check("nonmember isolation and group membership validation", async () => {
    await invite(second, c[0], member, 403);
    await request("GET /api/groups/{id}", 403, { token: member, params: { id: second } });
    await request("GET /api/groups/{id}/members", 403, { token: member, params: { id: second } });
    await request("GET /api/outings", 403, { token: member, query: "?groupId=" + second });
    await outingRequest(second, member, 403);
    await request("POST /api/groups", 400, { token: owner, body: {} });
    await invite(first, "invalid-number", owner, 400);
  });
  let linkedOuting: string | undefined;
  await check("create linked group outing and deny outsider access", async () => {
    const id = (await outingRequest(second)).data.id as string;
    linkedOuting = id;
    assert.equal(await prisma.outings.count({ where: { id, group_id: second } }), 1);
    await request("DELETE /api/groups/{id}", 409, { token: owner, params: { id: second } });
    const key = randomUUID();
    await request("POST /api/outings", 409, { token: owner, body: {
      group_id: second, title: marker, vote_deadline_hours: 2, create_request_key: key,
      initial_vote_options: [{ label: "Valid" }, { label: "Missing place", place_id: randomUUID() }],
    } });
    assert.equal(await prisma.outings.count({ where: { created_by: ownerProof.uid, create_request_key: key } }), 0);
    await request("GET /api/outings/{id}", 403, { token: member, params: { id } });
    await request("POST /api/outings/{id}/save", 403, { token: member, params: { id } });
    for (const suffix of ["attendance", "guests", "vote-options", "votes", "voting-state"]) {
      await request("GET /api/outings/{id}/" + suffix, 403, { token: member, params: { id } });
    }
  });

  await check("unregistered phone persisted in multiple groups without a fake user", async () => {
    const formatted = c[0].slice(0, 4) + " " + c[0].slice(4);
    const results = await Promise.all([
      invite(second, formatted, owner, [201, 409]), invite(second, c[0], owner, [201, 409]),
      invite(third, c[0], owner, 201),
    ]);
    assert.deepEqual(results.slice(0, 2).map(row => row.status).sort(), [201, 409]);
    const pending = await prisma.group_invitations.findMany({ where: { invited_phone: c[0], status: "pending" } });
    assert.deepEqual(pending.map(row => row.group_id).sort(), [second, third].sort());
    assert.ok(pending.every(row => row.user_id === null));
    for (const row of pending) {
      const roster = await request("GET /api/groups/{id}/members", 200, {
        token: owner, params: { id: row.group_id },
      });
      assert.equal(roster.data.length, 1);
      assert.deepEqual(roster.json.pending_members, [
        { invitation_id: row.id, phone: c[0], status: "pending" },
      ]);
    }
    assert.equal(await prisma.users.count({ where: { phone: c[0] } }), 0);
    await assert.rejects(auth.getUserByPhoneNumber(c[0]), { code: "auth/user-not-found" });
    // Simulate elapsed time on an isolated fixture and verify the pending association still links.
    await prisma.group_invitations.updateMany({ where: { id: pending[0].id }, data: { expires_at: new Date(0) } });
  });

  await check("owner can revoke pending phone association and recipient has no decline route", async () => {
    const pending = (await invite(revoked, c[0], owner, 201)).data;
    const key = "DELETE /api/groups/{id}/pending-memberships/{invitationId}";
    const params = { id: revoked, invitationId: pending.invitation_id };
    await request(key, 403, { token: member, params });
    await request(key, 200, { token: owner, params });
    const roster = await request("GET /api/groups/{id}/members", 200, {
      token: owner, params: { id: revoked },
    });
    assert.deepEqual(roster.json.pending_members, []);
    await request(key, 404, { token: owner, params });
    await request("POST /api/groups/invitations/{invitationId}/decline", 404, { token: member, params });
    await request("POST /api/groups/invitations/{invitationId}/accept", 404, { token: member, params });
  });
  await check("wrong Firebase identity cannot claim another verified phone", async () => {
    await request("POST /api/auth/signup", 401, { body: { name: marker, password, phone: c[0], phoneVerificationToken: registeredProof.token } });
    await request("POST /api/users/sync", 200, { token: member, body: { phone: c[0] } });
    assert.equal(await prisma.group_members.count({ where: { user_id: registeredProof.uid, group_id: { in: [second, third] } } }), 0);
  });

  const futureProof = await otp(...c);
  let future = futureProof.token;
  await check("first registration resolves every association amid concurrent adds and retries", async () => {
    const [session, retry] = await Promise.all([
      signup(c[0], futureProof.token), signup(c[0], futureProof.token),
      invite(race, c[0], owner, [201, 409]),
      request("POST /api/users/sync", 200, { token: futureProof.token, body: { name: marker } }),
    ]);
    assert.equal(session.data.uid, futureProof.uid);
    assert.equal(retry.data.uid, futureProof.uid);
    future = session.data.idToken;
    await Promise.all([
      request("POST /api/users/sync", 200, { token: futureProof.token, body: {} }),
      request("POST /api/users/sync", 200, { token: future, body: {} }),
      login(c[0]),
    ]);
    const visible = (await listGroups(future)).data;
    assert.deepEqual(visible.map((row: { id: string }) => row.id).sort(), [second, third, race].sort());
    assert.ok(visible.every((row: { my_role: string }) => row.my_role === "member"));
    assert.equal(await prisma.users.count({ where: { phone: c[0], id: futureProof.uid } }), 1);
    assert.equal(await prisma.group_members.count({ where: { user_id: futureProof.uid } }), 3);
    for (const id of [second, third, race]) {
      const roster = await request("GET /api/groups/{id}/members", 200, { token: owner, params: { id } });
      assert.equal(roster.data.filter((row: { user_id: string }) => row.user_id === futureProof.uid).length, 1);
      assert.deepEqual(roster.json.pending_members, []);
    }
    assert.equal(await prisma.group_invitations.count({ where: { invited_phone: c[0], status: "pending" } }), 0);
    assert.equal(await prisma.group_invitations.count({ where: { invited_phone: c[0], status: "revoked", user_id: null, group_id: revoked } }), 1);
    await request("GET /api/groups/{id}", 200, { token: future, params: { id: second } });
    if (linkedOuting) {
      const outings = await request("GET /api/outings", 200, { token: future, query: "?groupId=" + second });
      assert.ok(outings.data.some((row: { id: string }) => row.id === linkedOuting));
      await request("GET /api/outings/{id}", 200, { token: future, params: { id: linkedOuting } });
    }
    const relogin = (await login(c[0])).data;
    assert.deepEqual((await listGroups(relogin.idToken)).data.map((row: { id: string }) => row.id).sort(), [second, third, race].sort());
  });

  await check("registered removal persists after verified sync and login", async () => {
    await request("DELETE /api/groups/{id}/members/{userId}", 200, { token: owner, params: { id: third, userId: futureProof.uid } });
    await request("POST /api/users/sync", 200, { token: future, body: {} });
    assert.equal(await prisma.group_members.count({ where: { group_id: third, user_id: futureProof.uid } }), 0);
    await request("GET /api/groups/{id}", 403, { token: future, params: { id: third } });
    await request("POST /api/groups/{id}/members", 201, { token: owner, params: { id: first }, body: { phoneNumber: c[0] } });
    await request("POST /api/groups/{id}/members", 409, { token: owner, params: { id: first }, body: { phoneNumber: c[0] } });
    await request("DELETE /api/groups/{id}", 200, { token: owner, params: { id: revoked } });
  });


  const get = (key: string, token = owner, params?: Record<string, string>, query?: string) =>
    request(key, 200, { token, params, query });

  await check("profiles, passwords and FCM token persistence", async () => {
    assert.equal((await get("GET /api/users/cuser")).data.id, ownerProof.uid);
    assert.equal((await get("GET /api/users/{id}", owner, { id: futureProof.uid })).data.id, futureProof.uid);
    assert.ok((await get("GET /api/users")).data.some((row: { id: string }) => row.id === ownerProof.uid));
    await request("PATCH /api/users/cuser", 200, { token: owner, body: { name: marker + "-profile" } });
    assert.equal((await prisma.users.findUniqueOrThrow({ where: { id: ownerProof.uid } })).name, marker + "-profile");
    await request("DELETE /api/users/{id}", 403, { token: member, params: { id: ownerProof.uid } });
    await request("POST /api/auth/login", 401, { body: { phone: a[0], password: randomUUID() } });
    await request("POST /api/auth/verify-password", 200, { token: owner, body: { password } });
    const newPassword = randomUUID();
    await request("POST /api/auth/change-password", 200, { token: owner, body: { currentPassword: password, newPassword } });
    await request("POST /api/auth/verify-password", 200, { token: owner, body: { password: newPassword } });
    const deviceToken = randomUUID();
    const body = { token: deviceToken, platform: "test" };
    await request("POST /api/users/cuser/fcm-token", 201, { token: owner, body });
    const remove = await request("DELETE /api/users/cuser/fcm-token", 200, { token: member, body });
    assert.equal(remove.data.deleted, 0);
    assert.equal(await prisma.user_fcm_tokens.count({ where: { token: deviceToken, user_id: ownerProof.uid } }), 1);
    await request("DELETE /api/users/cuser/fcm-token/{token}", 200, { token: owner, params: { token: deviceToken } });
    assert.equal(await prisma.user_fcm_tokens.count({ where: { token: deviceToken } }), 0);
  });

  await check("draft isolation and persistence", async () => {
    const draft = (await request("POST /api/outings/drafts", 201, { token: owner, body: { title: marker } })).data;
    assert.ok((await get("GET /api/outings/drafts")).data.some((row: { id: string }) => row.id === draft.id));
    await request("PATCH /api/outings/drafts/{id}", 403, { token: member, params: { id: draft.id }, body: { title: "No" } });
    await request("PATCH /api/outings/drafts/{id}", 200, { token: owner, params: { id: draft.id }, body: { title: marker + "-1" } });
    assert.equal((await prisma.outing_drafts.findUniqueOrThrow({ where: { id: draft.id } })).title, marker + "-1");
    await request("DELETE /api/outings/drafts/{id}", 200, { token: owner, params: { id: draft.id } });
  });

  await check("places, discovery, metadata and saved places", async () => {
    const place = (await request("POST /api/places", 201, { token: owner, body: {
      name: marker, latitude: 30.05, longitude: 31.24, featured: true,
    } })).data;
    const id = place.id;
    placeIds.add(id);
    await get("GET /api/places/{id}", owner, { id });
    assert.ok((await request("GET /api/places", 200, { query: "?featured=true" })).data.some((row: { id: string }) => row.id === id));
    assert.ok((await request("GET /api/places/nearby", 200, { query: "?lat=30.05&lng=31.24" })).data.some((row: { id: string }) => row.id === id));
    await request("GET /api/places/nearby", 400, { query: "?lat=&lng=31.24" });
    await request("PATCH /api/places/{id}", 200, { token: owner, params: { id }, body: { area: marker } });
    const hour = (await request("PUT /api/places/{id}/hours", 200, { token: owner, params: { id }, body: {
      day: "monday", opens_at: "09:00", closes_at: "18:00",
    } })).data;
    assert.equal((await get("GET /api/places/{id}/hours", owner, { id })).data[0].id, hour.id);
    await request("POST /api/places/{id}/images", 400, { token: owner, params: { id }, body: {} });
    const image = (await request("POST /api/places/{id}/images", 201, { token: owner, params: { id }, body: {
      image_url: "https://example.invalid/" + marker, caption: marker,
    } })).data;
    assert.equal((await get("GET /api/places/{id}/images", owner, { id })).data[0].id, image.id);
    const price = (await request("POST /api/places/{id}/prices", 201, { token: owner, params: { id }, body: { label: marker, amount: 27 } })).data;
    assert.equal((await get("GET /api/places/{id}/prices", owner, { id })).data[0].id, price.id);
    assert.equal(await prisma.place_images.count({ where: { id: image.id, place_id: id } }), 1);
    await request("POST /api/places/{id}/save", 201, { token: member, params: { id } });
    await request("POST /api/places/{id}/save", 201, { token: member, params: { id } });
    assert.equal(await prisma.saved_places.count({ where: { place_id: id, user_id: registeredProof.uid } }), 1);
    assert.equal((await get("GET /api/places/saved", member)).data[0].place_id, id);
    await request("DELETE /api/places/{id}/save", 200, { token: member, params: { id } });
    await request("DELETE /api/places/{id}/hours/{hourId}", 404, { token: owner, params: { hourId: hour.id } });
    await request("DELETE /api/places/{id}/images/{imageId}", 404, { token: owner, params: { imageId: image.id } });
    await request("DELETE /api/places/{id}/prices/{priceId}", 404, { token: owner, params: { priceId: price.id } });
    await request("DELETE /api/places/{id}/hours/{hourId}", 200, { token: owner, params: { id, hourId: hour.id } });
    await request("DELETE /api/places/{id}/images/{imageId}", 200, { token: owner, params: { id, imageId: image.id } });
    await request("DELETE /api/places/{id}/prices/{priceId}", 200, { token: owner, params: { id, priceId: price.id } });
    await request("DELETE /api/places/{id}", 200, { token: owner, params: { id } });
  });
  await check("geocoding request validation and configured availability", async () => {
    await request("POST /api/places/geocoding", 400, { token: owner, body: {} });
    const result = await request("POST /api/places/geocoding", 200, { token: owner, body: { kind: "search", query: "Cairo", language: "en" } });
    assert.ok(Array.isArray(result.data.results));
    if (!result.data.available) cases["external geocoding lookup"] = "BLOCKED provider disabled";
  });

  await check("voting, attendance, chat and saved outings", async () => {
    assert.ok(linkedOuting);
    const id = linkedOuting;
    const params = { id, outingId: id };
    await request("PATCH /api/outings/{id}", 403, { token: future, params, body: { title: "Denied" } });
    await request("PATCH /api/outings/{id}", 200, { token: owner, params, body: { title: marker + "-v" } });
    assert.ok((await get("GET /api/outings/cuser", future)).data.some((row: { id: string }) => row.id === id));
    await request("PUT /api/outings/{id}/attendance", 200, { token: future, params, body: { status: "going" } });
    await get("GET /api/outings/{id}/attendance", future, params);
    assert.equal(await prisma.outing_attendance.count({ where: { outing_id: id, user_id: futureProof.uid, status: "going" } }), 1);
    await request("PUT /api/outings/{id}/attendance", 400, { token: future, params, body: { status: "wrong" } });
    const extra = (await request("POST /api/outings/{id}/vote-options", 201, { token: owner, params, body: { label: "Extra" } })).data;
    await request("DELETE /api/outings/{id}/vote-options/{optionId}", 404, { token: owner, params: { id: randomUUID(), optionId: extra.id } });
    await request("DELETE /api/outings/{id}/vote-options/{optionId}", 200, { token: owner, params: { id, optionId: extra.id } });
    await request("PUT /api/outings/{id}/vote-options", 200, { token: owner, params, body: { options: [{ label: "Venue 1" }, { label: "Venue 2" }] } });
    const [option1, option2] = (await get("GET /api/outings/{id}/vote-options", future, params)).data;
    await request("POST /api/outings/{id}/votes", 403, { token: member, params, body: { option_id: option1.id } });
    const vote = (option_id: string, token = future) => request("POST /api/outings/{id}/votes", 201, { token, params, body: { option_id } });
    await Promise.all([vote(option1.id), vote(option1.id)]);
    assert.equal(await prisma.outing_votes.count({ where: { outing_id: id, user_id: futureProof.uid } }), 1);
    await get("GET /api/outings/{id}/votes", future, params);
    await request("DELETE /api/outings/{id}/votes/{optionId}", 404, { token: future, params: { id, optionId: option2.id } });
    await request("DELETE /api/outings/{id}/votes/{optionId}", 200, { token: future, params: { id, optionId: option1.id } });
    await vote(option1.id);
    await request("DELETE /api/outings/{id}/votes", 200, { token: future, params });
    await vote(option1.id);
    await vote(option2.id, owner);
    await get("GET /api/outings/{id}/voting-state", future, params);
    await request("POST /api/outings/{id}/tie-break", 200, { token: owner, params });
    assert.ok((await prisma.outings.findUniqueOrThrow({ where: { id } })).winning_option_id);
    const body = { text: marker, clientMessageId: randomUUID() };
    const messages = await Promise.all([
      request("POST /api/outings/{outingId}/messages", 201, { token: future, params, body }),
      request("POST /api/outings/{outingId}/messages", 201, { token: future, params, body }),
    ]);
    assert.equal(messages[0].data.id, messages[1].data.id);
    const messageId = messages[0].data.id;
    assert.equal(await prisma.chat_messages.count({ where: { outing_id: id, sender_id: futureProof.uid } }), 1);
    await get("GET /api/outings/{outingId}/messages", owner, params);
    await request("PATCH /api/outings/{outingId}/read", 200, { token: owner, params, body: { lastReadMessageId: messageId } });
    await Promise.all([
      request("POST /api/outings/{id}/save", 201, { token: future, params }),
      request("POST /api/outings/{id}/save", 201, { token: future, params }),
    ]);
    assert.equal(await prisma.saved_outings.count({ where: { user_id: futureProof.uid, outing_id: id } }), 1);
    assert.equal((await get("GET /api/outings/saved", future)).data[0].outing_id, id);
    await request("DELETE /api/outings/{id}/save", 200, { token: future, params });
  });

  await check("Socket.IO authentication, room isolation and persisted delivery", async () => {
    assert.ok(linkedOuting);
    const outingId = linkedOuting;
    const sockets = [future, member, "invalid-id-token"].map(token => connectSocket(base, {
      auth: { token }, transports: ["websocket"], reconnection: false, autoConnect: false,
    }));
    const [participant, outsider, invalid] = sockets;
    try {
      const deadline = AbortSignal.timeout(10000);
      const connections = [
        socketEvent(participant, "connect", deadline),
        socketEvent(outsider, "connect", deadline),
        socketEvent(invalid, "connect_error", deadline),
      ];
      sockets.forEach(socket => socket.connect());
      const [, , error] = await Promise.all(connections);
      assert.ok(error instanceof Error);
      assert.equal(error.message, "UNAUTHORIZED");
      assert.equal((await participant.timeout(5000).emitWithAck("outing:join", { outingId })).ok, true);
      assert.equal((await outsider.timeout(5000).emitWithAck("outing:join", { outingId })).error, "FORBIDDEN");
      const delivery = socketEvent(participant, "outing:message", deadline);
      const sent = await request("POST /api/outings/{outingId}/messages", 201, {
        token: owner, params: { outingId }, body: { text: marker, clientMessageId: randomUUID() },
      });
      const delivered = await delivery as { id: string; sender: string };
      assert.equal(delivered.id, sent.data.id);
      assert.equal(delivered.sender, sent.data.sender);
      participant.disconnect();
      const reconnected = socketEvent(participant, "connect", AbortSignal.timeout(10000));
      participant.connect();
      await reconnected;
      assert.equal((await participant.timeout(5000).emitWithAck("outing:join", { outingId })).ok, true);
      const recovered = await request("GET /api/outings/{outingId}/messages", 200, {
        token: future, params: { outingId }, query: "?limit=40",
      });
      assert.equal(recovered.data.filter((item: { id: string }) => item.id === sent.data.id).length, 1);
      assert.equal(await prisma.chat_messages.count({ where: { id: sent.data.id, outing_id: outingId } }), 1);
      assert.equal((await participant.timeout(5000).emitWithAck("outing:leave", { outingId })).ok, true);
    } finally {
      sockets.forEach(socket => socket.disconnect());
    }
  });

  await check("special event guest lifecycle, notifications and cancellation", async () => {
    const body = {
      title: marker, occasion: "birthday", scheduled_at: new Date(Date.now() + 86400000),
      location_name: "Fixture venue", vote_deadline_hours: 2,
      create_request_key: randomUUID(),
      ...(!hasAutomaticWhatsApp() ? { guest_phones: [c[0], c[0]], guest_phones_whatsapp_opt_in: true } : {}),
    };
    const event = await request("POST /api/outings", 201, { token: owner, body });
    const id = event.data.id;
    if (!hasAutomaticWhatsApp()) assert.equal(event.data.manual_whatsapp_urls.length, 1);
    const params = { id, userId: registeredProof.uid };
    assert.equal((await request("POST /api/outings", 201, { token: owner, body })).data.id, id);
    assert.equal(await prisma.outing_attendance.count({ where: { outing_id: id, user_id: ownerProof.uid, status: "going" } }), 1);
    const ownEvent = (await request("POST /api/outings", 201, {
      token: member, body: { title: marker, occasion: "birthday", vote_deadline_hours: 2 },
    })).data;
    await request("PATCH /api/outings/{id}", 403, {
      token: member, params: { id: ownEvent.id }, body: { group_id: second, occasion: "none" },
    });
    await request("DELETE /api/users/cuser", 409, { token: member });
    await request("DELETE /api/outings/{id}", 200, { token: member, params: { id: ownEvent.id } });
    await request("POST /api/outings/{id}/guests", 201, { token: owner, params, body: { user_id: registeredProof.uid } });
    await get("GET /api/outings/{id}/guests", owner, params);
    await request("POST /api/outings/{id}/invitations/decline", 200, { token: member, params });
    await request("GET /api/outings/{id}", 403, { token: member, params });
    await request("DELETE /api/outings/{id}/guests/{userId}", 200, { token: owner, params });
    await request("POST /api/outings/{id}/guests", 201, { token: owner, params, body: { user_id: registeredProof.uid } });
    const responses = await Promise.all([
      request("POST /api/outings/{id}/invitations/accept", [200, 409], { token: member, params }),
      request("POST /api/outings/{id}/invitations/decline", [200, 409], { token: member, params }),
    ]);
    assert.deepEqual(responses.map(response => response.status).sort(), [200, 409]);
    if (responses[0].status === 409) {
      await request("POST /api/outings/{id}/guests", 201, { token: owner, params, body: { user_id: registeredProof.uid } });
      await request("POST /api/outings/{id}/invitations/accept", 200, { token: member, params });
    }
    const duplicate = await request("POST /api/outings/{id}/guests", 201, { token: owner, params, body: { user_id: registeredProof.uid } });
    assert.equal(duplicate.data.status, "accepted");
    assert.equal(await prisma.outing_guests.count({ where: { outing_id: id, user_id: registeredProof.uid, status: "accepted" } }), 1);
    const inbox = (await get("GET /api/notifications", member)).data;
    const notification = inbox.find((row: { outing_id: string }) => row.outing_id === id);
    assert.ok(notification);
    assert.ok(await prisma.notification_events.count({
      where: { outing_id: id, recipient_user_id: registeredProof.uid, channel: "push" },
    }));
    await request("PATCH /api/notifications/{id}/read", 403, { token: owner, params: { id: notification.id } });
    await request("PATCH /api/notifications/{id}/read", 200, { token: member, params: { id: notification.id } });
    await request("PATCH /api/notifications/read", 200, { token: member });
    await request("POST /api/outings/{id}/cancel", 200, { token: owner, params });
    await request("DELETE /api/outings/{id}", 200, { token: owner, params });
  });

  await exerciseGroupOutingFeatures({
    groupId: second, owner, ownerId: ownerProof.uid,
    future, memberId: futureProof.uid, outsider: member,
    renewSession: async () => (await login(c[0])).data.idToken,
  });

  await check("self-deletion REST aliases", async () => {
    await request("DELETE /api/users/{id}", 200, { token: member, params: { id: registeredProof.uid } });
    await request("GET /api/users/cuser", 404, { token: member });
    const syncGroup = await group();
    await invite(syncGroup, b[0], owner, 201);
    const sync = await request("POST /api/users/sync", 200, { token: registeredProof.token, body: {} });
    assert.equal(sync.data.id, registeredProof.uid);
    assert.equal(await prisma.group_members.count({ where: { group_id: syncGroup, user_id: registeredProof.uid } }), 1);
    assert.equal((await listGroups(registeredProof.token)).data[0].id, syncGroup);
    await request("DELETE /api/users/cuser", 200, { token: registeredProof.token });
    assert.equal(await prisma.users.count({ where: { id: registeredProof.uid } }), 0);
  });

  }
} catch (error) {
  const detail = error instanceof assert.AssertionError ? error.message.split("\n")[0] : "Unexpected dependency or request error";
  cases["fixture setup"] = "BLOCKED " + detail;
  console.log("AUDIT_BLOCKER", detail);
} finally {
  await check("remove only isolated Neon and Firebase fixtures", async () => {
    const ids = [...registered];
    const fixtures = await prisma.outings.findMany({ where: { created_by: { in: ids } }, select: { id: true } });
    const outingIds = fixtures.map(row => row.id);
    const fixtureGroups = await prisma.groups.findMany({ where: { created_by: { in: ids } }, select: { id: true } });
    const groupIds = fixtureGroups.map(row => row.id);
    await prisma.$transaction([
      prisma.notification_events.deleteMany({ where: { OR: [
        { recipient_user_id: { in: ids } }, { recipient_phone: { in: phones } },
        { outing_id: { in: outingIds } }, { group_id: { in: groupIds } },
      ] } }),
      prisma.outings.deleteMany({ where: { id: { in: outingIds } } }),
      prisma.groups.deleteMany({ where: { id: { in: groupIds } } }),
      prisma.places.deleteMany({ where: { id: { in: [...placeIds] } } }),
      prisma.users.deleteMany({ where: { id: { in: ids } } }),
    ]);
    assert.equal(await prisma.users.count({ where: { phone: { in: phones } } }), 0);
    assert.equal(await prisma.group_invitations.count({ where: { invited_phone: { in: phones } } }), 0);
    for (const uid of ids) {
      await auth.deleteUser(uid);
      await assert.rejects(auth.getUser(uid), { code: "auth/user-not-found" });
    }
  });
  server.closeAllConnections();
  await realtime.close();
  await prisma.$disconnect();
  for (const gap of contractGaps) console.log("AUDIT_CONTRACT", gap);
  console.log("AUDIT_RESULT", JSON.stringify({ operations: operations.map(op => op.key), statuses, cases, contractGaps: [...contractGaps] }));
  if (contractGaps.size || Object.entries(cases).some(([label, status]) => label !== "external geocoding lookup" && status !== "PASS")) process.exitCode = 1;
}
