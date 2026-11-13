/** OpenAPI-driven HTTP verification. No fixtures, credentials, workers or data mutations. */
import "dotenv/config";
import fs from "node:fs";
import path from "node:path";
import app from "../src/app.js";
import { swaggerSpec } from "../src/config/swagger.js";
import { prisma } from "../src/config/database.js";

const spec = swaggerSpec as any;
const originalError = console.error;
console.error = (message, ...args) => {
  if (typeof message === "string" && message.startsWith("[Firebase Auth]")) return;
  originalError(message, ...args);
};
const failures: string[] = [];
const methods = new Set(["get", "post", "put", "patch", "delete", "options", "head"]);
const operations = Object.entries(spec.paths).flatMap(([url, item]: [string, any]) =>
  Object.entries(item).filter(([method]) => methods.has(method)).map(([method, op]: [string, any]) => ({ url, method, ...op })));
const ids = new Set<string>();
function resolve(ref: string) {
  return ref.startsWith("#/") ? ref.slice(2).split("/").reduce((value, key) => value?.[key.replace(/~1/g, "/").replace(/~0/g, "~")], spec) : undefined;
}
let refs = 0;
function walk(value: any) {
  if (!value || typeof value !== "object") return;
  if (value.$ref) { refs++; if (!resolve(value.$ref)) failures.push(`Unresolved ${value.$ref}`); }
  for (const child of Object.values(value)) walk(child);
}
walk(spec);
for (const op of operations) {
  if (!op.operationId || ids.has(op.operationId)) failures.push(`Duplicate/missing operationId ${op.operationId}`);
  ids.add(op.operationId);
  const params = (op.parameters ?? []).map((p: any) => p.$ref ? resolve(p.$ref) : p);
  for (const name of [...op.url.matchAll(/\{([^}]+)\}/g)].map(m => m[1])) {
    if (!params.some((p: any) => p?.in === "path" && p.name === name && p.required)) failures.push(`Missing path parameter ${op.operationId}:${name}`);
  }
  for (const p of params) if (p?.in === "path" && !op.url.includes(`{${p.name}}`)) failures.push(`Extra path parameter ${op.operationId}:${p.name}`);
}

// Compare registered route declarations in the mounted route modules only.
const registered = new Set<string>();
const root = path.resolve("src/routes");
for (const feature of fs.readdirSync(root, { withFileTypes: true }).filter(e => e.isDirectory())) {
  const directory = path.join(root, feature.name);
  const index = fs.readFileSync(path.join(directory, "index.ts"), "utf8");
  const prefix = index.match(/router\.use\(\s*["']([^"']+)["']/)?.[1];
  if (!prefix) { failures.push(`Unknown route mount ${feature.name}`); continue; }
  for (const file of fs.readdirSync(directory).filter(f => f.endsWith(".ts"))) {
    const source = fs.readFileSync(path.join(directory, file), "utf8");
    for (const match of source.matchAll(/\b(router|api)\.(get|post|put|patch|delete)\(\s*["']([^"']+)["']/g)) {
      const url = (prefix + (match[3] === "/" ? "" : match[3])).replace(/:([A-Za-z][\w]*)/g, "{$1}");
      registered.add(`${match[2]} ${url}`);
    }
  }
}
const documented = new Set(operations.map(op => `${op.method} ${op.url}`));
for (const route of registered) if (!documented.has(route)) failures.push(`Undocumented production route ${route}`);
for (const op of operations.filter(op => op.url.startsWith("/api/"))) if (!registered.has(`${op.method} ${op.url}`)) failures.push(`Unregistered documented route ${op.method} ${op.url}`);

const server = app.listen(0, "127.0.0.1");
await new Promise<void>(r => server.once("listening", r));
const address = server.address();
if (!address || typeof address === "string") throw new Error("No listener");
const base = `http://127.0.0.1:${address.port}`;
const rows: { scenario: string; result: string; status?: number }[] = [];
function schemaCheck(schema: any, value: any): void {
  if (!schema) return;
  if (schema.$ref) return schemaCheck(resolve(schema.$ref), value);
  if (value === null && schema.nullable) return;
  for (const part of schema.allOf ?? []) schemaCheck(part, value);
  if (schema.type === "object") {
    if (!value || typeof value !== "object" || Array.isArray(value)) throw Error("Expected object");
    for (const key of schema.required ?? []) if (!(key in value)) throw Error(`Missing ${key}`);
    for (const [key, child] of Object.entries(schema.properties ?? {})) if (key in value) schemaCheck(child, value[key]);
  } else if (schema.type === "array") {
    if (!Array.isArray(value)) throw Error("Expected array");
    for (const item of value) schemaCheck(schema.items, item);
  } else if (schema.type === "integer") {
    if (!Number.isInteger(value)) throw Error("Expected integer");
  } else if (schema.type && typeof value !== schema.type) throw Error(`Expected ${schema.type}`);
  if (schema.enum && !schema.enum.includes(value)) throw Error("Invalid enum");
}
async function request(op: any, expected: number, body?: unknown) {
  const url = op.url.replace(/\{[^}]+\}/g, "00000000-0000-4000-8000-000000000000");
  try {
    const response = await fetch(base + url, { method: op.method.toUpperCase(), headers: body === undefined ? {} : { "Content-Type": "application/json" }, body: body === undefined ? undefined : JSON.stringify(body), signal: AbortSignal.timeout(15000) });
    const json = await response.json();
    if (response.status !== expected) throw Error(`Expected ${expected}, observed ${response.status}`);
    const responseSpec = op.responses?.[String(expected)];
    const resolved = responseSpec?.$ref ? resolve(responseSpec.$ref) : responseSpec;
    schemaCheck(resolved?.content?.["application/json"]?.schema, json);
    rows.push({ scenario: `${op.operationId}: ${expected === 401 ? "missing authentication" : "HTTP contract"}`, result: "PASS", status: response.status });
    return json;
  } catch (error) { rows.push({ scenario: `${op.operationId}: ${String(error)}`, result: "FAIL" }); }
}
try {
  const live = await fetch(base + "/api-docs/swagger-ui-init.js");
  const initializer = await live.text();
  const optionsText = initializer.split("var options = ")[1]?.split(/;\r?\n/)[0];
  if (!optionsText) throw new Error("Swagger initializer lacks options");
  const liveSpec = JSON.parse(optionsText).swaggerDoc;
  rows.push({ scenario: "Served OpenAPI matches generated specification", result: JSON.stringify(liveSpec) === JSON.stringify(spec) ? "PASS" : "FAIL", status: live.status });
  const ui = await fetch(base + "/api-docs/");
  rows.push({ scenario: "Swagger UI available", result: ui.status === 200 ? "PASS" : "FAIL", status: ui.status });
  for (const op of operations) {
    const security = op.security ?? spec.security;
    if (security?.length) await request(op, 401);
  }
  for (const id of ["signup", "login"]) {
    const op = operations.find(op => op.operationId.toLowerCase() === id || op.url === `/api/auth/${id}`);
    if (op) await request(op, 400, {});
  }
  let placeId: string | undefined;
  for (const id of ["getRoot", "getHealth", "listPlaces"]) {
    const op = operations.find(op => op.operationId === id);
    if (op) {
      const json = await request(op, 200);
      if (id === "listPlaces") placeId = json?.data?.[0]?.id;
    }
  }
  for (const id of ["getPlace", "listPlaceHours", "listPlaceImages", "listPlacePrices"]) {
    const op = operations.find(op => op.operationId === id);
    if (!op) continue;
    if (placeId) await request({ ...op, url: op.url.replace("{id}", encodeURIComponent(placeId)) }, 200);
    else rows.push({ scenario: `${id}: no existing public place available`, result: "NOT VERIFIED" });
  }
  const nearby = operations.find(op => op.operationId === "listNearbyPlaces");
  if (nearby) await request({ ...nearby, url: nearby.url + "?lat=30.0444&lng=31.2357" }, 200);
  for (const [scenario, url, method, body, attempts] of [
    ["Authentication rate limit", "/api/auth/login", "POST", {}, 25],
    ["Global API rate limit", "/api/users/cuser", "GET", undefined, 305],
  ] as const) {
    let limited = false;
    for (let i = 0; i < attempts; i++) {
      const response = await fetch(base + url, { method, headers: body ? { "Content-Type": "application/json" } : {}, body: body ? JSON.stringify(body) : undefined });
      const json = await response.json();
      if (response.status === 429) {
        limited = json.success === false && typeof json.message === "string" && Number(response.headers.get("Retry-After")) > 0;
        break;
      }
    }
    rows.push({ scenario, result: limited ? "PASS" : "FAIL", ...(limited ? { status: 429 } : {}) });
  }
  for (const domain of ["AUTH successful signup/session/profile", "GROUPS create/invite/accept/decline/membership/owner protection/deletion", "INVITATIONS verified-phone discovery/history/concurrent decisions", "OUTINGS create/update/cancel/list/creator permissions", "DRAFTS CRUD/idempotency/version conflict", "VOTING proposals/votes/state/closure", "ATTENDANCE RSVP/check-in/location/access", "CHAT authenticated REST/access", "PLACES curator success/ordinary-user 403", "NOTIFICATIONS pagination/read/read-all/cancellation", "MEDIA presign/confirm/delete authorization"]) {
    rows.push({ scenario: domain, result: "NOT VERIFIED" });
  }
} finally {
  await new Promise<void>((resolve, reject) => server.close(error => error ? reject(error) : resolve()));
  await prisma.$disconnect();
}
const result = { generatedAt: new Date().toISOString(), productionApiRoutes: registered.size, operations: operations.length, uniqueOperationIds: ids.size, refsChecked: refs, structuralFailures: [...new Set(failures)], curatorConfigured: Boolean(process.env.PLACES_CURATOR_UIDS?.trim()), scenarios: rows, notes: ["Ephemeral loopback listener of the current local Express app; no scheduled workers.", "No authenticated test identity supplied; no users, credentials or successful responses invented.", "No application data created, changed or deleted. Swagger browser Execute interaction and Socket.IO delivery not exercised.", "No Flutter tests, launch, emulator or device checks."] };
fs.writeFileSync("../docs/audit/CONFIRMED_FIXES_OPENAPI_RESULTS.json", JSON.stringify(result, null, 2) + "\n");
console.log(JSON.stringify({ ...result, scenarios: { pass: rows.filter(r => r.result === "PASS").length, fail: rows.filter(r => r.result === "FAIL"), notVerified: rows.filter(r => r.result === "NOT VERIFIED").length } }, null, 2));
process.exitCode = failures.length || rows.some(r => r.result === "FAIL") ? 1 : 0;
