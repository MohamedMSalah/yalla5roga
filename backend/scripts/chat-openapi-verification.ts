/** Live HTTP checks selected exclusively by generated OpenAPI operation IDs.
 * No workers, sockets, Flutter, service unit tests or existing-user mutations.
 * Direct database calls are limited to disposable fixture setup and cleanup.
 */
import "dotenv/config";
import assert from "node:assert/strict";
import { randomUUID } from "node:crypto";
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

const server = app.listen(0, "127.0.0.1");
await new Promise<void>(resolve => server.once("listening", resolve));
const address = server.address();
assert.ok(address && typeof address !== "string");
const base = `http://127.0.0.1:${address.port}`;
async function call(id: string, expected: number, options: {
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
  assert.equal(response.status, expected, `${id}: expected ${expected}, got ${response.status}`);
  assert.equal(json.success, expected < 400);
  if (expected >= 400) assert.equal(typeof json.message, 'string');
  const contract = op.operation.responses[String(expected)];
  assert.ok(contract, `${id}: status absent from OpenAPI`);
  const responseContract = (contract as any).$ref
    ? (contract as any).$ref.slice(2).split('/').reduce((o: any, k: string) => o[k], spec)
    : contract;
  validate(responseContract.content?.['application/json']?.schema ?? {}, json);
  rows.push(`| ${id} | ${expected} | PASS |`);
  return json;
}

const ids = [0, 1, 2].map(() => `chat-audit-${randomUUID()}`);
const firebaseIds: string[] = [];
const seededIds: string[] = [];
let groupId: string | undefined;
let outingId: string | undefined;
let failure: unknown;
try {
  const auth = getFirebaseAuth();
  const tokens: string[] = [];
  for (const [index, uid] of ids.entries()) {
    await auth.createUser({ uid });
    firebaseIds.push(uid);
    tokens.push((await signInWithCustomTokenSession(await auth.createCustomToken(uid))).idToken);
    await prisma.users.create({ data: { id: uid, name: ["Audit Owner", "عضو الاختبار", "Audit Outsider"][index]!,
      phone: `+1555${String(Date.now()).slice(-6)}${index}` } });
    seededIds.push(uid);
  }
  const group = await prisma.groups.create({ data: { name: "Chat API audit", created_by: ids[0]!,
    group_members: { create: [{ user_id: ids[0]!, role: "owner" }, { user_id: ids[1]!, role: "member" }] } } });
  groupId = group.id;
  const outing = await prisma.outings.create({ data: { title: "Chat API audit", group_id: groupId,
    created_by: ids[0]!, status: "draft", occasion: "none", vote_ends_at: new Date(Date.now() + 86400000) } });
  outingId = outing.id;
  const params = { outingId };
  const owner = tokens[0]!, member = tokens[1]!, outsider = tokens[2]!;
  for (const token of [undefined, "invalid-token"]) {
    await call("getCurrentUser", 401, { token });
    await call("sendOutingMessage", 401, { token, params, body: { text: "Rejected" } });
  }
  await call("getCurrentUser", 200, { token: owner });
  await call("syncUser", 200, { token: owner, body: {} });
  await call("syncUser", 200, { token: owner, body: {} });
  await call("sendOutingMessage", 403, { token: outsider, params, body: { text: "Rejected" } });
  await call("listOutingMessages", 403, { token: outsider, params });
  await call("sendOutingMessage", 400, { token: owner, params, body: { text: " " } });
  await call("sendOutingMessage", 400, { token: owner, params, body: { text: `<@${ids[2]}|Spoof>` } });
  await call("sendOutingMessage", 400, { token: owner, params, body: { text: "<@%ZZ|Bad>" } });
  const key = randomUUID();
  const body = { text: `Hello <@${ids[1]}|Spoof> and <@${ids[0]}|Self> <@${ids[1]}|Repeated>`, clientMessageId: key };
  const sent = await call("sendOutingMessage", 201, { token: owner, params, body });
  assert.equal(sent.data.sender, "Audit Owner");
  assert.ok(sent.data.text.includes(encodeURIComponent("عضو الاختبار")));
  assert.ok(!sent.data.text.includes("Spoof"));
  const retries = await Promise.all([0, 1].map(() => call("sendOutingMessage", 201, { token: owner, params, body })));
  assert.ok(retries.every(r => r.data.id === sent.data.id));
  const inbox = await call("listNotifications", 200, { token: member });
  const mentions = inbox.data.filter((n: any) => n.messageId === sent.data.id);
  assert.equal(mentions.length, 1);
  assert.match(mentions[0].body, /mentioned you/);
  assert.equal(mentions[0].eventType, "chat_message");
  assert.equal(mentions[0].outing_id, outingId);
  const ownInbox = await call("listNotifications", 200, { token: owner });
  assert.ok(!ownInbox.data.some((n: any) => n.messageId === sent.data.id));
  const history = await call("listOutingMessages", 200, { token: member, params, query: { limit: "1" } });
  assert.equal(history.data[0].text, sent.data.text);
  assert.equal(history.data[0].sender, "Audit Owner");
  await call("sendOutingMessage", 201, { token: member, params, body: { text: "Reply", clientMessageId: randomUUID() } });
  const latest = await call("listOutingMessages", 200, { token: owner, params, query: { limit: "1" } });
  assert.equal(latest.data[0].sender, "عضو الاختبار");
  const older = await call("listOutingMessages", 200, { token: owner, params, query: { limit: "1", before: latest.next_cursor } });
  assert.equal(older.data[0].id, sent.data.id);
  const focused = await call("listOutingMessages", 200, { token: member, params, query: { messageId: sent.data.id } });
  assert.equal(focused.data[0].text, sent.data.text);
  await call("updateCurrentUser", 200, { token: member, body: { name: "Updated Neon Name" } });
  const recoveredToken = (await signInWithCustomTokenSession(await auth.createCustomToken(ids[0]!))).idToken;
  const recoveredHistory = await call("listOutingMessages", 200, { token: recoveredToken, params, query: { limit: "1" } });
  assert.equal(recoveredHistory.data[0].sender, "Updated Neon Name");
  await call("listOutingMessages", 400, { token: member, params, query: { limit: "0" } });
  await call("markOutingChatRead", 200, { token: member, params });
  await call("markNotificationRead", 403, { token: outsider, params: { id: mentions[0].id } });
  await call("markNotificationRead", 200, { token: member, params: { id: mentions[0].id } });
  await call("markAllNotificationsRead", 200, { token: member });
  await call("cancelOuting", 200, { token: owner, params: { id: outingId } });
  await call("sendOutingMessage", 409, { token: owner, params, body: { text: "Closed" } });
  const closedRetry = await call("sendOutingMessage", 201, { token: owner, params, body });
  assert.equal(closedRetry.data.id, sent.data.id);
  const after = await call("listNotifications", 200, { token: member });
  assert.equal(after.data.filter((n: any) => n.messageId === sent.data.id).length, 1);
} catch (error) {
  failure = error;
  console.error("OpenAPI verification failed:", error instanceof Error ? error.message : "Unknown dependency failure");
} finally {
  // Delete only UUID-tracked fixtures created above. Delivery workers never ran.
  if (seededIds.length) {
  await prisma.notification_events.deleteMany({ where: { recipient_user_id: { in: seededIds } } });
  if (outingId) await prisma.outings.delete({ where: { id: outingId } });
  if (groupId) await prisma.groups.delete({ where: { id: groupId } });
  await prisma.users.deleteMany({ where: { id: { in: ids } } });
  }
  for (const uid of firebaseIds) await getFirebaseAuth().deleteUser(uid);
  await prisma.$disconnect();
  await new Promise<void>(resolve => server.close(() => resolve()));
  const report = `# Chat OpenAPI verification\n\nRun: 2026-11-11, Africa/Cairo. ${failure ? "INCOMPLETE / FAILED" : "PASS"}.\n\n` +
    `All application HTTP calls used generated OpenAPI operation IDs and declared response schemas. Real Firebase custom-session tokens and Neon PostgreSQL; disposable fixtures only. No workers or external message delivery.\n\n` +
    `| OpenAPI operation | HTTP status | Result |\n| --- | --- | --- |\n${rows.join("\n")}\n\n` +
    `Flutter runtime, UI/widget/integration tests, Socket.IO delivery/reconnect, offline queue recovery and device push delivery were not exercised. Swagger UI browser Execute controls were not tested.\n`;
  writeFileSync(new URL("../../docs/audit/CHAT_REALTIME_OPENAPI_VERIFICATION.md", import.meta.url), report);
  console.log(`OpenAPI checks passed: ${rows.length}; fixture cleanup completed; overall ${failure ? "FAILED" : "PASS"}`);
}
if (failure) process.exitCode = 1;
