/** Only HTTP operations selected from served OpenAPI; disposable database schema. */
import "dotenv/config";
import assert from "node:assert/strict";
import { randomUUID } from "node:crypto";
import { readFileSync, readdirSync, writeFileSync } from "node:fs";
import { Client } from "pg";
import express from "express";
import swaggerUi from "swagger-ui-express";

const schema = `phase5_api_${randomUUID().replaceAll("-", "")}`;
const url = new URL(process.env.DATABASE_URL!);
url.searchParams.delete("channel_binding"); url.searchParams.delete("pgbouncer");
url.searchParams.set("sslmode", process.env.PHASE3_SECURE_TUNNEL === "1" ? "disable" : "verify-full");
url.hostname = url.hostname.replace("-pooler.", ".");
const admin = new Client({ connectionString: url.toString(), ssl: process.env.PHASE3_SECURE_TUNNEL === "1" && url.hostname === "127.0.0.1" ? false : { rejectUnauthorized: true }, connectionTimeoutMillis: 15000 });
url.searchParams.set("schema", schema); url.searchParams.set("connection_limit", "1");
process.env.DATABASE_URL = url.toString(); process.env.NODE_ENV = "test";
let db: import("@prisma/client").PrismaClient | undefined, server: import("node:http").Server | undefined, made = false;
const rows: any[] = [];
try {
  await admin.connect(); assert.match(schema, /^phase5_api_[a-f0-9]{32}$/);
  await admin.query(`CREATE SCHEMA "${schema}"`); made = true;
  await admin.query(`SET search_path TO "${schema}"`);
  for (const m of readdirSync("prisma/migrations").filter(n => /^\d/.test(n)).sort())
    await admin.query(readFileSync(`prisma/migrations/${m}/migration.sql`, "utf8").replace('CREATE SCHEMA IF NOT EXISTS "public";', ''));
  const owner = "phase5-owner", member = "phase5-member", outsider = "phase5-outsider", group = randomUUID(), outing = randomUUID(), other = randomUUID();
  await admin.query(`INSERT INTO users(id,name,phone) VALUES ($1,'Owner','+15550005001'),($2,'Member','+15550005002'),($3,'Outsider','+15550005003')`, [owner, member, outsider]);
  await admin.query(`INSERT INTO groups(id,name,created_by) VALUES ($1,'Phase 5 group',$2)`, [group, owner]);
  await admin.query(`INSERT INTO group_members(group_id,user_id,role) VALUES ($1,$2,'owner'),($1,$3,'member')`, [group, owner, member]);
  for (const id of [outing, other]) await admin.query(`INSERT INTO outings(id,title,created_by,group_id,status,scheduled_at) VALUES ($1,'Phase 5 outing',$2,$3,'confirmed',now()+interval '1 day')`, [id, owner, group]);
  db = (await import("../src/config/database.js")).prisma;
  await db.$executeRawUnsafe(`SET search_path TO "${schema}"`);
  assert.equal(((await db.$queryRawUnsafe("SELECT current_schema() AS schema")) as any[])[0].schema, schema);
  const { swaggerSpec } = await import("../src/config/swagger.js"), spec = swaggerSpec as any;
  const operations = new Map<string, any>();
  for (const [path, item] of Object.entries(spec.paths) as any) for (const [method, op] of Object.entries(item) as any)
    if (op.operationId) operations.set(op.operationId, { path, method, ...op });
  const { createAuthMiddleware } = await import("../src/middleware/auth.middleware.js");
  const { UnauthorizedError } = await import("../src/utils/errors.js");
  const { errorMiddleware } = await import("../src/middleware/error.middleware.js");
  const app = express(); app.use(express.json()); app.use("/api-docs", swaggerUi.serve, swaggerUi.setup(spec));
  app.use(createAuthMiddleware(async token => {
    if (![owner, member, outsider].includes(token)) throw new UnauthorizedError("Invalid fixture token");
    return { uid: token };
  }));
  app.use("/api/outings", (await import("../src/routes/outings/outing.chat.routes.js")).default);
  app.use(errorMiddleware); server = app.listen(0, "127.0.0.1");
  await new Promise<void>(done => server!.once("listening", done));
  const base = `http://127.0.0.1:${(server.address() as import("node:net").AddressInfo).port}`;
  const resolve = (ref: string): any => ref.slice(2).split("/").reduce((v: any, k: string) => v[k], spec);
  function validate(s: any, v: any): void {
    if (!s) return; if (s.$ref) return validate(resolve(s.$ref), v); if (v === null && s.nullable) return;
    for (const a of s.allOf ?? []) validate(a, v);
    if (s.enum) assert.ok(s.enum.includes(v));
    if (s.type === "object") { assert.ok(v && typeof v === "object"); for (const k of s.required ?? []) assert.ok(k in v); for (const [k, c] of Object.entries(s.properties ?? {})) if (k in v) validate(c, v[k]); }
    else if (s.type === "array") { assert.ok(Array.isArray(v)); for (const c of v) validate(s.items, c); }
    else if (s.type === "integer") assert.ok(Number.isInteger(v)); else if (s.type) assert.equal(typeof v, s.type);
  }
  let active: string = outing, messageId: string = randomUUID();
  async function call(id: string, status: number, token: string | null = owner, body?: unknown, query = "") {
    const op = operations.get(id); assert.ok(op, `Undocumented ${id}`);
    const path = op.path.replace("{outingId}", active).replace("{messageId}", messageId);
    const response = await fetch(base + path + query, { method: op.method.toUpperCase(), headers: { ...(token ? { Authorization: `Bearer ${token}` } : {}), ...(body === undefined ? {} : { "Content-Type": "application/json" }) }, body: body === undefined ? undefined : JSON.stringify(body), signal: AbortSignal.timeout(30000) });
    const json = await response.json() as any;
    assert.equal(response.status, status, `${id}: ${JSON.stringify(json)}`);
    const r = op.responses[String(status)]; assert.ok(r, `${id}: undocumented ${status}`);
    validate((r.$ref ? resolve(r.$ref) : r).content?.["application/json"]?.schema, json);
    rows.push({ scenario: id, status, result: "PASS" }); return json;
  }
  assert.equal((await fetch(base + "/api-docs/")).status, 200);
  const init = await (await fetch(base + "/api-docs/swagger-ui-init.js")).text();
  assert.deepEqual(JSON.parse(init.split("var options = ")[1]!.split(/;\r?\n/)[0]!).swaggerDoc, spec);
  rows.push({ scenario: "Served Swagger matches generated OpenAPI", result: "PASS" });
  for (const id of ["listOutingMessages", "sendOutingMessage", "markOutingChatRead", "editOutingMessage", "deleteOutingMessage"])
    for (const token of [null, "invalid"]) await call(id, 401, token, id === "listOutingMessages" ? undefined : { text: "Hello" });
  const key = randomUUID();
  messageId = (await call("sendOutingMessage", 201, owner, { text: "First message", clientMessageId: key })).data.id;
  assert.equal((await call("sendOutingMessage", 201, owner, { text: "Retry", clientMessageId: key })).data.id, messageId);
  await call("editOutingMessage", 403, member, { text: "Not mine" }); await call("deleteOutingMessage", 403, member);
  await call("editOutingMessage", 403, outsider, { text: "Not participant" }); await call("listOutingMessages", 403, outsider);
  active = other; await call("editOutingMessage", 404, owner, { text: "Wrong outing" }); active = outing;
  await call("editOutingMessage", 400, owner, { text: " " }); await call("editOutingMessage", 400, owner, { text: "x".repeat(2001) });
  const saved = (await call("editOutingMessage", 200, owner, { text: `<@${member}|Wrong>` })).data;
  assert.ok(saved.text.includes("Member"));
  assert.equal((await call("listOutingMessages", 200, member, undefined, `?messageId=${messageId}`)).data[0].text, saved.text);
  assert.equal((await call("deleteOutingMessage", 200)).data.text, ""); assert.equal((await call("deleteOutingMessage", 200)).data.text, "");
  await call("editOutingMessage", 409, owner, { text: "Cannot restore" });
  assert.equal((await call("sendOutingMessage", 201, owner, { text: "Retry after deletion", clientMessageId: key })).data.text, "");
  messageId = (await call("sendOutingMessage", 201, member, { text: "Second" })).data.id;
  await admin.query(`UPDATE chat_messages SET sent_at=now()-interval '55 seconds' WHERE id=$1`, [messageId]);
  await call("editOutingMessage", 200, member, { text: "Edited inside one minute" });
  await admin.query(`UPDATE chat_messages SET sent_at=now()-interval '60 seconds' WHERE id=$1`, [messageId]);
  const expired = await call("editOutingMessage", 409, member, { text: "Too late" });
  assert.equal(expired.message, "MESSAGE_EDIT_WINDOW_EXPIRED");
  assert.equal((await call("listOutingMessages", 200, member, undefined, `?messageId=${messageId}`)).data[0].text, "Edited inside one minute");
  await call("deleteOutingMessage", 200, member);
  messageId = (await call("sendOutingMessage", 201, member, { text: "Fresh closure fixture" })).data.id;
  rows.push({ scenario: "Own edit succeeds before 60 seconds, fails at 60 seconds without content changes; own deletion still succeeds", result: "PASS" });
  for (const status of ["past", "cancelled"]) {
    await admin.query(`UPDATE outings SET status=$2::outing_status WHERE id=$1`, [outing, status]);
    await call("listOutingMessages", 200, member); await call("markOutingChatRead", 200, member);
    await call("sendOutingMessage", 409, member, { text: "Closed" }); await call("editOutingMessage", 409, member, { text: "Closed" }); await call("deleteOutingMessage", 409, member);
  }
  await admin.query(`UPDATE outings SET status='confirmed', scheduled_at=now()-interval '2 hours' WHERE id=$1`, [outing]);
  await call("listOutingMessages", 200, member); await call("markOutingChatRead", 200, member);
  await call("sendOutingMessage", 409, member, { text: "Two hours elapsed" }); await call("editOutingMessage", 409, member, { text: "Closed" }); await call("deleteOutingMessage", 409, member);
  await admin.query(`UPDATE outings SET scheduled_at=now()-interval '119 minutes' WHERE id=$1`, [outing]);
  await admin.query(`UPDATE chat_messages SET sent_at=now() WHERE id=$1`, [messageId]);
  await call("editOutingMessage", 200, member, { text: "Still open" });
  for (let i = 0; i < 3; i++) await call("sendOutingMessage", 201, owner, { text: `Page ${i}`, clientMessageId: randomUUID() });
  const page = await call("listOutingMessages", 200, member, undefined, "?limit=2"); assert.equal(page.data.length, 2); assert.ok(page.next_cursor);
  const older = await call("listOutingMessages", 200, member, undefined, `?limit=2&before=${page.next_cursor}`);
  assert.ok(older.data.every((x: any) => !page.data.some((y: any) => x.id === y.id)));
  rows.push({ scenario: "Own-message authorization, tombstone deduplication, canonical mentions, closed history, two-hour cutoff and cursor paging", result: "PASS" });
} catch (error) {
  rows.push({ scenario: "HTTP/OpenAPI verification", result: "BLOCKED", reason: error instanceof Error ? error.name + ": " + ((error as any).code ?? "verification failure") : "Unknown" });
  throw error;
} finally {
  if (server) await new Promise<void>(done => server!.close(() => done())); await db?.$disconnect();
  if (made) { await admin.query("ROLLBACK"); assert.match(schema, /^phase5_api_[a-f0-9]{32}$/); await admin.query(`DROP SCHEMA "${schema}" CASCADE`); }
  await admin.end();
  writeFileSync("../docs/audit/PHASE_5_OPENAPI_RESULTS.json", JSON.stringify({ checkedAt: new Date().toISOString(), mode: "HTTP/OpenAPI only; disposable schema; controlled Firebase verifier; no workers or live migration", cleanup: made ? "Disposable schema removed" : "No test schema created", rows }, null, 2) + "\n");
  console.log(JSON.stringify({ checks: rows.length, cleanup: "complete" }));
}
