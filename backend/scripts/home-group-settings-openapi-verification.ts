/** Only HTTP operations selected from served OpenAPI; disposable database schema. */
import "dotenv/config";
import assert from "node:assert/strict";
import { randomUUID } from "node:crypto";
import { readFileSync, readdirSync, writeFileSync } from "node:fs";
import { Client } from "pg";
import express from "express";
import swaggerUi from "swagger-ui-express";

const schema = `settings_api_${randomUUID().replaceAll("-", "")}`;
const url = new URL(process.env.DATABASE_URL!);
url.searchParams.delete("channel_binding");
url.searchParams.delete("pgbouncer");
url.searchParams.set(
  "sslmode",
  process.env.PHASE3_SECURE_TUNNEL === "1" ? "disable" : "verify-full",
);
url.hostname = url.hostname.replace("-pooler.", ".");
const admin = new Client({
  connectionString: url.toString(),
  ssl:
    process.env.PHASE3_SECURE_TUNNEL === "1" && url.hostname === "127.0.0.1"
      ? false
      : { rejectUnauthorized: true },
  connectionTimeoutMillis: 15000,
});
url.searchParams.set("schema", schema);
url.searchParams.set("connection_limit", "1");
process.env.DATABASE_URL = url.toString();
process.env.NODE_ENV = "test";
let db: import("@prisma/client").PrismaClient | undefined,
  server: import("node:http").Server | undefined,
  made = false;
const rows: any[] = [];
const oldError = console.error;
console.error = (m, ...args) => {
  if (
    typeof m === "string" &&
    (m.startsWith("[Firebase Auth]") || m.startsWith("[Firebase Admin]"))
  )
    return;
  oldError(m, ...args);
};
try {
  await admin.connect();
  assert.match(schema, /^settings_api_[a-f0-9]{32}$/);
  await admin.query(`CREATE SCHEMA "${schema}"`);
  made = true;
  await admin.query(`SET search_path TO "${schema}"`);
  for (const m of readdirSync("prisma/migrations")
    .filter((n) => /^\d/.test(n))
    .sort())
    await admin.query(
      readFileSync(`prisma/migrations/${m}/migration.sql`, "utf8").replace(
        'CREATE SCHEMA IF NOT EXISTS "public";',
        "",
      ),
    );
  const owner = "settings-owner",
    member = "settings-member",
    invitee = "settings-invitee",
    outsider = "settings-outsider";
  const phones = new Map([
    [owner, "+201000091001"],
    [member, "+201000091002"],
    [invitee, "+201000091003"],
    [outsider, "+201000091004"],
  ]);
  for (const [uid, phone] of phones)
    await admin.query(`INSERT INTO users(id,name,phone) VALUES ($1,$2,$3)`, [
      uid,
      uid.replace("push-", ""),
      phone,
    ]);
  db = (await import("../src/config/database.js")).prisma;
  await db.$executeRawUnsafe(`SET search_path TO "${schema}"`);
  assert.equal(
    (
      (await db.$queryRawUnsafe("SELECT current_schema() AS schema")) as any[]
    )[0].schema,
    schema,
  );
  // Only Firebase's network boundary is controlled. Application routes/use cases/SQL are real.
  const { getFirebaseAuth } = await import("../src/config/firebase.js");
  const auth = getFirebaseAuth();
  auth.verifyIdToken = (async (token: string) => {
    if (!phones.has(token))
      throw Object.assign(new Error("Invalid fixture token"), {
        code: "auth/invalid-id-token",
      });
    return {
      uid: token,
      phone_number: phones.get(token),
      firebase: { sign_in_provider: "custom" },
    };
  }) as any;
  auth.getUser = (async (uid: string) => ({
    uid,
    phoneNumber: phones.get(uid),
    disabled: false,
  })) as any;
  auth.getUserByPhoneNumber = (async (phone: string) => {
    const found = [...phones].find(([, p]) => p === phone);
    if (!found)
      throw Object.assign(new Error("Not registered"), {
        code: "auth/user-not-found",
      });
    return { uid: found[0], phoneNumber: phone, disabled: false };
  }) as any;
  const { swaggerSpec } = await import("../src/config/swagger.js"),
    spec = swaggerSpec as any;
  const operations = new Map<string, any>();
  for (const [path, item] of Object.entries(spec.paths) as any)
    for (const [method, op] of Object.entries(item) as any)
      if (op.operationId)
        operations.set(op.operationId, { path, method, ...op });
  const { errorMiddleware } =
    await import("../src/middleware/error.middleware.js");
  const app = express();
  app.use(express.json());
  app.use("/api-docs", swaggerUi.serve, swaggerUi.setup(spec));
  for (const feature of [
    "groups",
    "outings",
    "invitations",
    "notifications",
    "users",
  ])
    app.use((await import(`../src/routes/${feature}/index.js`)).default);
  app.use(errorMiddleware);
  server = app.listen(0, "127.0.0.1");
  await new Promise<void>((done) => server!.once("listening", done));
  const base = `http://127.0.0.1:${(server.address() as import("node:net").AddressInfo).port}`;
  const resolve = (ref: string): any =>
    ref
      .slice(2)
      .split("/")
      .reduce((v: any, k: string) => v[k], spec);
  function validate(s: any, v: any): void {
    if (!s) return;
    if (s.$ref) return validate(resolve(s.$ref), v);
    if (v === null && s.nullable) return;
    for (const a of s.allOf ?? []) validate(a, v);
    if (s.enum) assert.ok(s.enum.includes(v), `Unexpected enum ${v}`);
    if (s.type === "object") {
      assert.ok(v && typeof v === "object");
      for (const k of s.required ?? []) assert.ok(k in v, `Missing ${k}`);
      for (const [k, c] of Object.entries(s.properties ?? {}))
        if (k in v) validate(c, v[k]);
    } else if (s.type === "array") {
      assert.ok(Array.isArray(v));
      for (const c of v) validate(s.items, c);
    } else if (s.type === "integer") assert.ok(Number.isInteger(v));
    else if (s.type) assert.equal(typeof v, s.type);
  }
  const ids: Record<string, string> = {
    id: randomUUID(),
    outingId: randomUUID(),
    invitationId: randomUUID(),
    messageId: randomUUID(),
    userId: member,
  };
  async function call(
    id: string,
    status = 200,
    token: string | null = owner,
    body?: unknown,
    query = "",
  ) {
    const op = operations.get(id);
    assert.ok(op, `Undocumented ${id}`);
    const path = op.path.replace(
      /\{(\w+)\}/g,
      (_: string, key: string) => ids[key] ?? ids.id!,
    );
    const response = await fetch(base + path + query, {
      method: op.method.toUpperCase(),
      headers: {
        ...(token ? { Authorization: `Bearer ${token}` } : {}),
        ...(body === undefined ? {} : { "Content-Type": "application/json" }),
      },
      body: body === undefined ? undefined : JSON.stringify(body),
      signal: AbortSignal.timeout(30000),
    });
    const json = (await response.json()) as any;
    assert.equal(response.status, status, `${id}: ${JSON.stringify(json)}`);
    const r = op.responses[String(status)];
    assert.ok(r, `${id}: undocumented ${status}`);
    validate(
      (r.$ref ? resolve(r.$ref) : r).content?.["application/json"]?.schema,
      json,
    );
    rows.push({ scenario: id, status, result: "PASS" });
    if (rows.length % 20 === 0)
      console.log(JSON.stringify({ checks: rows.length, last: id }));
    return json;
  }
  const init = await (await fetch(base + "/api-docs/swagger-ui-init.js")).text();
  assert.deepEqual(JSON.parse(init.split("var options = ")[1]!.split(/;\r?\n/)[0]!).swaggerDoc, spec);
  assert.ok(operations.get("deleteGroup").description.includes("sole active member"));
  assert.ok(!operations.get("updateGroup").description.includes("sole active member"));
  rows.push({ scenario: "Served Swagger/OpenAPI matches application contract", result: "PASS" });
  for (const id of ["deleteGroup", "getNotificationPreferences", "updateNotificationPreferences"])
    await call(id, 401, null, id === "updateNotificationPreferences" ? {} : undefined);
  const original = (await call("getNotificationPreferences", 200, owner)).data;
  const off = (await call("updateNotificationPreferences", 200, owner, { pushEnabled: false })).data;
  assert.equal(off.pushEnabled, false);
  assert.equal(off.chatMessages, original.chatMessages);
  assert.equal((await call("getNotificationPreferences", 200, owner)).data.pushEnabled, false);
  assert.equal((await call("listNotifications", 200, owner)).preferences.pushEnabled, false);
  assert.equal((await call("getNotificationPreferences", 200, member)).data.pushEnabled, true);
  assert.equal((await call("updateNotificationPreferences", 200, owner, { pushEnabled: true })).data.pushEnabled, true);
  assert.equal((await call("getNotificationPreferences", 200, owner)).data.pushEnabled, true);
  await call("updateNotificationPreferences", 400, owner, { pushEnabled: "yes" });
  ids.id = (await call("createGroup", 201, owner, { name: "Solo owner leave" })).data.id;
  assert.equal((await call("listGroupMembers")).data.length, 1);
  await call("deleteGroup", 403, outsider);
  await call("deleteGroup");
  await call("getGroup", 404);
  ids.id = (await call("createGroup", 201, owner, { name: "Other members protected" })).data.id;
  const group = ids.id;
  ids.invitationId = (await call("inviteToGroup", 201, owner, { phoneNumber: phones.get(member) })).data.invitation_id;
  await call("acceptGroupInvitation", 200, member);
  assert.equal((await call("listGroupMembers")).data.length, 2);
  await call("deleteGroup", 409);
  ids.userId = owner;
  await call("removeGroupMember", 403, owner);
  assert.equal((await call("listGroupMembers")).data.length, 2);
  ids.userId = member;
  await call("removeGroupMember", 200, member);
  assert.equal((await call("listGroupMembers")).data.length, 1);
  await call("deleteGroup");
  ids.id = (await call("createGroup", 201, owner, { name: "History remains protected" })).data.id;
  await call("createOuting", 201, owner, {
    title: "Preserved outing", group_id: ids.id,
    scheduled_at: new Date(Date.now() + 86400000).toISOString(),
    vote_deadline_hours: 3, create_request_key: randomUUID(),
    initial_vote_options: [{ label: "Cafe", latitude: 30, longitude: 31 }, { label: "Park", latitude: 30.01, longitude: 31.01 }],
  });
  await call("deleteGroup", 409);
  assert.equal((await call("listGroupMembers")).data.length, 1);
  rows.push({ scenario: "Sole-owner deletion preserves groups with historical outings", result: "PASS" });
} catch (error) {
  rows.push({ scenario: "HTTP/OpenAPI verification", result: "FAIL", reason: error instanceof Error ? error.message.replace(/postgres(?:ql)?:\/\/\S+/g, "[redacted]") : "Unknown" });
  process.exitCode = 1;
} finally {
  if (server) await new Promise<void>(done => server!.close(() => done()));
  await db?.$disconnect();
  if (made) {
    assert.match(schema, /^settings_api_[a-f0-9]{32}$/);
    await admin.query(`DROP SCHEMA "${schema}" CASCADE`);
  }
  await admin.end();
  console.error = oldError;
  writeFileSync("../docs/audit/HOME_GROUP_SETTINGS_OPENAPI_RESULTS.json", JSON.stringify({checkedAt: new Date().toISOString(), mode: "Served Swagger/OpenAPI HTTP, disposable PostgreSQL schema, controlled Firebase identity boundary; no application-schema changes or Flutter execution", cleanup: made ? "Disposable schema removed" : "No schema created", rows}, null, 2) + "\n");
  console.log(JSON.stringify({checks: rows.length, passed: rows.filter(r => r.result === "PASS").length, failed: rows.filter(r => r.result === "FAIL"), cleanup: "complete"}));
}
