/** OpenAPI HTTP and real Socket.IO client verification. Application actions
 * use public contracts; direct Neon/Firebase calls only create/clean fixtures.
 * No notification workers, SMS, Flutter runtime or UI tests. */
import { createServer } from "node:http";
import { io, type Socket } from "socket.io-client";
import { attachRealtime } from "../src/realtime/socket-server.js";
import "dotenv/config";
import assert from "node:assert/strict";
import { randomUUID, randomInt } from "node:crypto";
import { writeFileSync } from "node:fs";
import app from "../src/app.js";
import { swaggerSpec } from "../src/config/swagger.js";
import { prisma } from "../src/config/database.js";
import { getFirebaseAuth } from "../src/config/firebase.js";
import { signInWithCustomTokenSession } from "../src/config/firebase-client.js";

type Schema = { $ref?: string; allOf?: Schema[]; type?: string; required?: string[];
  properties?: Record<string, Schema>; items?: Schema; nullable?: boolean; enum?: unknown[] };
type Operation = { operationId: string; responses: Record<string, { content?: Record<string, { schema: Schema }> }> };
const spec = swaggerSpec as unknown as { paths: Record<string, Record<string, Operation>>; components: unknown };
const operations = new Map(Object.entries(spec.paths).flatMap(([path, methods]) =>
  Object.entries(methods).map(([method, operation]) => [operation.operationId, { path, method, operation }] as const)));
const rows: string[] = [];
function validate(schema: Schema, value: unknown): void {
  if (schema.$ref) {
    const resolved = schema.$ref.slice(2).split("/").reduce<any>((o, k) => o[k], spec);
    return validate(resolved, value);
  }
  if (value === null && schema.nullable) return;
  for (const part of schema.allOf ?? []) validate(part, value);
  if (schema.enum) assert.ok(schema.enum.includes(value));
  if (schema.type === "array") {
    assert.ok(Array.isArray(value));
    for (const item of value) if (schema.items) validate(schema.items, item);
  } else if (schema.type === "object") {
    assert.ok(value !== null && typeof value === "object" && !Array.isArray(value));
    const object = value as Record<string, unknown>;
    for (const key of schema.required ?? []) assert.ok(key in object, `Missing contract field ${key}`);
    for (const [key, child] of Object.entries(schema.properties ?? {})) if (key in object) validate(child, object[key]);
  } else if (schema.type === "integer") assert.ok(Number.isInteger(value));
  else if (schema.type) assert.equal(typeof value, schema.type);
}

const server = createServer(app);
const realtime = attachRealtime(server);
server.listen(0, "127.0.0.1");
await new Promise<void>(resolve => server.once("listening", resolve));
const address = server.address();
assert.ok(address && typeof address !== "string");
const base = `http://127.0.0.1:${address.port}`;
async function call(id: string, expected: number | number[], options: {
  token?: string; params?: Record<string, string>; query?: Record<string, string>; body?: unknown;
} = {}) {
  const op = operations.get(id);
  assert.ok(op, `Undocumented operation ${id}`);
  const path = op.path.replace(/\{(\w+)\}/g, (_, key) => {
    assert.ok(options.params?.[key], `Missing OpenAPI parameter ${key}`);
    return encodeURIComponent(options.params[key]!);
  });
  const response = await fetch(base + path + (options.query ? `?${new URLSearchParams(options.query)}` : ""), {
    method: op.method.toUpperCase(), headers: {
      ...(options.token ? { Authorization: `Bearer ${options.token}` } : {}),
      ...(options.body !== undefined ? { "Content-Type": "application/json" } : {}),
    }, body: options.body === undefined ? undefined : JSON.stringify(options.body),
    signal: AbortSignal.timeout(30000),
  });
  const json = await response.json();
  assert.ok((Array.isArray(expected) ? expected : [expected]).includes(response.status), `${id}: expected ${expected}, got ${response.status}: ${json.message ?? ""}`);
  expected = response.status;
  assert.equal(json.success, expected < 400);
  if (expected >= 400) assert.equal(typeof json.message, 'string');
  const contract = op.operation.responses[String(expected)];
  assert.ok(contract, `${id}: status absent from OpenAPI`);
  const responseContract = (contract as any).$ref
    ? (contract as any).$ref.slice(2).split('/').reduce((o: any, k: string) => o[k], spec)
    : contract;
  validate(responseContract.content?.['application/json']?.schema ?? {}, json);
  rows.push(`| ${id} | ${expected} | PASS |`);
  return { ...json, httpStatus: response.status };
}

type Change = { kind: string; id?: string; cursor: { epoch: string; sequence: number } };
const sockets: Socket[] = [];
const events = new Map<Socket, Change[]>();
const checks: string[] = [];
function passed(name: string) { checks.push(name); console.log(`PASS: ${name}`); }
async function connect(token: string) {
  const socket = io(base, { auth: { token, uid: "spoofed-identity" }, transports: ["websocket"],
    reconnection: false, autoConnect: false, forceNew: true });
  sockets.push(socket);
  events.set(socket, []);
  socket.on("data:changed", (change: Change) => events.get(socket)!.push(change));
  await new Promise<void>((resolve, reject) => {
    const timeout = setTimeout(() => reject(new Error("Socket connection timeout")), 15000);
    socket.once("connect", () => { clearTimeout(timeout); resolve(); });
    socket.once("connect_error", error => { clearTimeout(timeout); reject(error); });
    socket.connect();
  });
  return socket;
}
async function ack(socket: Socket, name: string, payload: unknown): Promise<any> {
  return socket.timeout(10000).emitWithAck(name, payload);
}
async function received(socket: Socket, kind: string, id: string, after = 0) {
  const deadline = Date.now() + 8000;
  while (Date.now() < deadline) {
    const change = events.get(socket)!.find(e => e.kind === kind && e.id === id && e.cursor.sequence > after);
    if (change) return change;
    await new Promise(resolve => setTimeout(resolve, 20));
  }
  throw new Error(`Missing ${kind} event for fixture ${id}`);
}
const fixtures: { uid: string; phone: string; token: string }[] = [];
const firebaseIds: string[] = [];
const groupIds: string[] = [];
const outingIds: string[] = [];
let failure: unknown;
let cleanup = false;
try {
  const auth = getFirebaseAuth();
  // Reserved fictional US numbers. Never attach a phone already in use.
  const candidates = Array.from({ length: 100 }, (_, i) => `+120255501${String(i).padStart(2, "0")}`)
    .sort(() => randomInt(3) - 1);
  for (const phone of candidates) {
    if (fixtures.length === 5) break;
    if (await prisma.users.findUnique({ where: { phone } })) continue;
    try { await auth.getUserByPhoneNumber(phone); continue; }
    catch (error) { if ((error as { code?: string }).code !== "auth/user-not-found") throw error; }
    const uid = `membership-audit-${randomUUID()}`;
    await auth.createUser({ uid, phoneNumber: phone, displayName: "Membership audit" });
    firebaseIds.push(uid);
    const token = (await signInWithCustomTokenSession(await auth.createCustomToken(uid))).idToken;
    fixtures.push({ uid, phone, token });
  }
  assert.equal(fixtures.length, 5);
  const [owner, member, outsider, newcomer, revoked] = fixtures as [typeof fixtures[number], typeof fixtures[number], typeof fixtures[number], typeof fixtures[number], typeof fixtures[number]];
  for (const fixture of [owner, member, outsider]) {
    const synced = await call("syncUser", 200, { token: fixture.token, body: { name: "Membership audit" } });
    assert.equal(synced.data.id, fixture.uid);
    assert.equal(synced.invitations.phoneVerified, true);
  }
  const ownerSocket = await connect(owner.token);
  const memberSocket = await connect(member.token);
  const secondDevice = await connect(member.token);
  const outsiderSocket = await connect(outsider.token);
  await assert.rejects(connect("invalid-token"), /UNAUTHORIZED/);
  passed("Real Firebase sessions; account rooms ignore spoofed UID; invalid socket token rejected");
  await call("createGroup", 401, { body: { name: "Rejected" } });
  const created = await call("createGroup", 201, { token: owner.token, body: { name: "Membership audit" } });
  const id: string = created.data.id;
  groupIds.push(id);
  assert.equal(created.data.member_count, 1);
  await received(ownerSocket, "group", id);
  const other = await call("createGroup", 201, { token: owner.token, body: { name: "Second audit" } });
  groupIds.push(other.data.id);
  await call("inviteToGroup", 403, { token: outsider.token, params: { id }, body: { phoneNumber: member.phone } });
  await call("inviteToGroup", 400, { token: owner.token, params: { id }, body: { phoneNumber: "not-a-phone" } });
  const added = await call("inviteToGroup", 201, { token: owner.token, params: { id },
    body: { phoneNumber: `+1 (202) 555-${member.phone.slice(-4)}` } });
  assert.equal(added.data.outcome, "member_added");
  assert.equal(added.data.member.user_id, member.uid);
  await Promise.all([ownerSocket, memberSocket, secondDevice].map(s => received(s, "membership", id)));
  assert.equal(events.get(outsiderSocket)!.length, 0);
  const roster = await call("listGroupMembers", 200, { token: member.token, params: { id } });
  assert.equal(roster.data.length, 2);
  assert.equal(roster.pending_members.length, 0);
  assert.ok(roster.data.some((m: any) => m.user_id === member.uid));
  const groups = await call("listCurrentUserGroups", 200, { token: member.token });
  assert.ok(groups.data.some((g: any) => g.id === id));
  passed("Normalized existing-user add is persisted before multi-device event delivery, without joining a group room");
  const beforeDuplicate = events.get(memberSocket)!.length;
  await Promise.all([0, 1].map(() => call("inviteToGroup", 409, { token: owner.token, params: { id }, body: { phoneNumber: member.phone } })));
  assert.equal(events.get(memberSocket)!.length, beforeDuplicate);
  assert.equal((await call("listGroupMembers", 200, { token: owner.token, params: { id } })).data.length, 2);
  assert.equal((await ack(memberSocket, "group:join", { groupId: id })).ok, true);
  assert.equal((await ack(outsiderSocket, "group:join", { groupId: id })).ok, false);
  assert.equal((await ack(memberSocket, "group:join", { groupId: "bad" })).error, "INVALID_GROUP_ID");
  await call("removeGroupMember", 403, { token: member.token, params: { id, userId: owner.uid } });
  await call("removeGroupMember", 403, { token: owner.token, params: { id, userId: owner.uid } });
  await call("updateGroup", 403, { token: member.token, params: { id }, body: { bio: "Denied" } });
  const checkpoint = (await ack(memberSocket, "data:reconcile", {})).cursor;
  await call("updateGroup", 200, { token: owner.token, params: { id }, body: { bio: "Live details" } });
  await received(memberSocket, "group", id, checkpoint.sequence);
  assert.equal((await call("getGroup", 200, { token: member.token, params: { id } })).data.bio, "Live details");
  passed("Duplicates are stable conflicts; group rooms and owner actions enforce current membership");

  // These verified Firebase identities have no Neon profile yet.
  const pending = await call("inviteToGroup", 201, { token: member.token, params: { id }, body: { phoneNumber: newcomer.phone } });
  assert.equal(pending.data.outcome, "invited");
  const repeated = await call("inviteToGroup", 409, { token: owner.token, params: { id }, body: { phoneNumber: newcomer.phone } });
  assert.equal(repeated.data.invitation_id, pending.data.invitation_id);
  await call("inviteToGroup", 201, { token: owner.token, params: { id: other.data.id }, body: { phoneNumber: newcomer.phone } });
  const pendingRoster = await call("listGroupMembers", 200, { token: member.token, params: { id } });
  assert.equal(pendingRoster.pending_members.length, 1);
  assert.equal(pendingRoster.data.length, 2);
  const newSocket = await connect(newcomer.token);
  const claimed = await call("syncUser", 200, { token: newcomer.token, body: { name: "New audit member" } });
  assert.deepEqual(new Set(claimed.invitations.claimedGroupIds), new Set(groupIds));
  await Promise.all(groupIds.map(groupId => received(newSocket, "membership", groupId)));
  assert.equal((await call("listCurrentUserGroups", 200, { token: newcomer.token })).data.length, 2);
  assert.equal((await call("listGroupMembers", 200, { token: newcomer.token, params: { id } })).pending_members.length, 0);
  assert.equal((await call("syncUser", 200, { token: newcomer.token, body: {} })).invitations.claimedGroupIds.length, 0);
  passed("Pending invitations across groups link once to the verified UID on first sync; every group and new user's socket is notified");
  const revoke = await call("inviteToGroup", 201, { token: owner.token, params: { id }, body: { phoneNumber: revoked.phone } });
  await call("revokePendingGroupMembership", 403, { token: member.token, params: { id, invitationId: revoke.data.invitation_id } });
  await call("revokePendingGroupMembership", 200, { token: owner.token, params: { id, invitationId: revoke.data.invitation_id } });
  await call("syncUser", 200, { token: revoked.token, body: {} });
  assert.equal((await call("listCurrentUserGroups", 200, { token: revoked.token })).data.length, 0);
  passed("Revoked pending invitation never becomes membership on registration");

  const outing = await call("createOuting", 201, { token: owner.token, body: {
    title: "Realtime audit", group_id: id, occasion: "none", vote_deadline_hours: 24,
  } });
  const outingId: string = outing.data.id;
  outingIds.push(outingId);
  await Promise.all([ownerSocket, memberSocket, secondDevice, newSocket].map(s => received(s, "outings", outingId)));
  const outingList = await call("listOutings", 200, { token: member.token, query: { groupId: id } });
  assert.ok(outingList.data.some((o: any) => o.id === outingId));
  await call("updateOuting", 403, { token: member.token, params: { id: outingId }, body: { title: "Denied update" } });
  const cursor = (await ack(memberSocket, "data:reconcile", {})).cursor;
  memberSocket.disconnect();
  await call("updateOuting", 200, { token: owner.token, params: { id: outingId }, body: { title: "Changed outing" } });
  await received(secondDevice, "outings", outingId, cursor.sequence);
  const recovered = await connect(member.token);
  const replay = await ack(recovered, "data:reconcile", cursor);
  assert.equal(replay.reset, false);
  assert.ok(replay.changes.some((c: Change) => c.id === outingId));
  assert.equal((await call("getOuting", 200, { token: member.token, params: { id: outingId } })).data.title, "Changed outing");
  const quiet = await ack(recovered, "data:reconcile", replay.cursor);
  assert.equal(quiet.reset, false);
  assert.deepEqual(quiet.changes, []);
  assert.equal((await ack(recovered, "data:reconcile", { epoch: "old-process", sequence: 0 })).reset, true);
  assert.deepEqual((await ack(outsiderSocket, "data:reconcile", cursor)).changes, []);
  await call("cancelOuting", 200, { token: owner.token, params: { id: outingId } });
  await received(recovered, "outing", outingId, replay.cursor.sequence);
  assert.equal((await call("getOuting", 200, { token: member.token, params: { id: outingId } })).data.status, "cancelled");
  passed("Outing create/update/cancel reaches all current members; missed events replay once and invalid cursors request recovery");

  assert.equal((await ack(recovered, "group:join", { groupId: id })).ok, true);
  const leaveCursor = (await ack(recovered, "data:reconcile", {})).cursor;
  await call("removeGroupMember", 200, { token: member.token, params: { id, userId: member.uid } });
  await received(recovered, "membership", id, leaveCursor.sequence);
  await received(ownerSocket, "membership", id, leaveCursor.sequence);
  assert.equal((await ack(recovered, "group:join", { groupId: id })).ok, false);
  await call("getGroup", 403, { token: member.token, params: { id } });
  await call("listOutings", 403, { token: member.token, query: { groupId: id } });
  assert.equal((await call("listCurrentUserGroups", 200, { token: member.token })).data.length, 0);
  const afterLeave = events.get(recovered)!.length;
  await call("updateGroup", 200, { token: owner.token, params: { id }, body: { bio: "After leave" } });
  assert.equal(events.get(recovered)!.length, afterLeave);
  const concurrent = await Promise.all([0, 1].map(() => call("inviteToGroup", [201, 409], {
    token: owner.token, params: { id }, body: { phoneNumber: member.phone },
  })));
  assert.deepEqual(concurrent.map(r => r.httpStatus).sort(), [201, 409]);
  assert.equal((await call("listGroupMembers", 200, { token: member.token, params: { id } })).data.filter((m: any) => m.user_id === member.uid).length, 1);
  await call("getOuting", 200, { token: member.token, params: { id: outingId } });
  assert.equal(events.get(outsiderSocket)!.length, 0);
  passed("Self-leave revokes access and subscriptions; concurrent re-add creates one membership and restores outing access");
} catch (error) {
  failure = error;
  console.error("Verification failed:", error instanceof Error ? error.message : "Unknown failure");
} finally {
  for (const socket of sockets) socket.disconnect();
  // Only tracked fixtures; do not run workers or send messages to real users.
  try {
    const ids = firebaseIds;
    if (ids.length) {
      await prisma.notification_events.deleteMany({ where: { OR: [
        { recipient_user_id: { in: ids } }, { group_id: { in: groupIds } }, { outing_id: { in: outingIds } },
      ] } });
      await prisma.outings.deleteMany({ where: { created_by: { in: ids } } });
      await prisma.groups.deleteMany({ where: { created_by: { in: ids } } });
      await prisma.users.deleteMany({ where: { id: { in: ids } } });
      for (const uid of firebaseIds) await getFirebaseAuth().deleteUser(uid);
      assert.equal(await prisma.users.count({ where: { id: { in: ids } } }), 0);
    }
    cleanup = true;
  } catch (error) {
    failure ??= error;
    console.error("Fixture cleanup failed; inspect tracked fixture IDs in this run");
  }
  await prisma.$disconnect();
  await new Promise<void>(resolve => realtime.close(() => resolve()));
  const report = `# Group membership and Socket.IO contract verification\n\nRun: 2026-11-11 (Africa/Cairo). **${failure ? "FAILED / INCOMPLETE" : "PASS"}**. Fixture cleanup: ${cleanup ? "verified" : "FAILED"}.\n\n` +
    `Real Firebase custom-session authentication, production Express routes and Neon persistence. HTTP operations and response validation come from generated OpenAPI. Socket.IO clients use the same authenticated server. No Flutter execution, UI tests, SMS or notification workers.\n\n` +
    checks.map(c => `- ${c}`).join("\n") + "\n\n| OpenAPI operation | Status | Result |\n| --- | --- | --- |\n" + rows.join("\n") +
    "\n\nLimitations: real SMS OTP/signup UI and legacy identity repair were not exercised. First registration was verified through the supported verified-phone sync API. No production backend/client release or multi-instance delivery test.\n";
  writeFileSync(new URL("../../docs/audit/GROUP_REALTIME_OPENAPI_VERIFICATION.md", import.meta.url), report);
  console.log(`OpenAPI calls passed: ${rows.length}; scenarios: ${checks.length}; cleanup: ${cleanup}; overall ${failure ? "FAIL" : "PASS"}`);
}
if (failure) process.exitCode = 1;

