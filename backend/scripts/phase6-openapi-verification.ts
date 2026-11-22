/** Phase 6: OpenAPI-driven, read-only HTTP contract verification. No workers or fixtures. */
import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import app from "../src/app.js";
import { swaggerSpec } from "../src/config/swagger.js";
import { prisma } from "../src/config/database.js";

const spec = swaggerSpec as any;
const rows: Array<{ scenario: string; result: string; status?: number }> = [];
const resolve = (ref: string): any =>
  ref
    .slice(2)
    .split("/")
    .reduce((v: any, key: string) => v?.[key], spec);
function check(schema: any, value: any): void {
  if (!schema) return;
  if (schema.$ref) return check(resolve(schema.$ref), value);
  if (value === null && schema.nullable) return;
  for (const part of schema.allOf ?? []) check(part, value);
  if (schema.type === "object") {
    assert.ok(value && typeof value === "object" && !Array.isArray(value));
    for (const key of schema.required ?? [])
      assert.ok(key in value, `Missing ${key}`);
    for (const [key, child] of Object.entries(schema.properties ?? {}))
      if (key in value) check(child, value[key]);
  } else if (schema.type === "array") {
    assert.ok(Array.isArray(value));
    for (const item of value) check(schema.items, item);
  } else if (schema.type === "integer") assert.ok(Number.isInteger(value));
  else if (schema.type) assert.equal(typeof value, schema.type);
  if (schema.enum) assert.ok(schema.enum.includes(value));
}
const operationIds = [
  "deleteCurrentUser",
  "getCurrentUser",
  "listSavedOutings",
  "getOuting",
  "listCurrentUserOutings",
];
const operations = Object.entries(spec.paths)
  .flatMap(([url, item]: [string, any]) =>
    Object.entries(item).map(([method, op]: [string, any]) => ({
      url,
      method,
      ...op,
    })),
  )
  .filter((op) => operationIds.includes(op.operationId));
assert.equal(operations.length, operationIds.length);
for (const operationId of [
  "loginWithPhonePassword",
  "signupWithPhonePassword",
  "startPasswordRecovery",
  "verifyPasswordRecovery",
  "resetRecoveredPassword",
]) {
  const op = Object.values(spec.paths)
    .flatMap((item: any) => Object.values(item))
    .find((op: any) => op.operationId === operationId) as any;
  assert.ok(
    op?.requestBody && (op?.responses?.["200"] || op?.responses?.["201"]),
    operationId,
  );
  rows.push({
    scenario: `${operationId}: existing request and success contracts present`,
    result: "PASS",
  });
}
const server = app.listen(0, "127.0.0.1");
await new Promise<void>((done) => server.once("listening", done));
const address = server.address();
if (!address || typeof address === "string") throw Error("No listener");
const base = `http://127.0.0.1:${address.port}`;
const originalError = console.error;
console.error = (message, ...args) => {
  if (typeof message === "string" && message.startsWith("[Firebase Auth]"))
    return;
  originalError(message, ...args);
};
try {
  const ui = await fetch(base + "/api-docs/");
  assert.equal(ui.status, 200);
  const init = await (
    await fetch(base + "/api-docs/swagger-ui-init.js")
  ).text();
  const options = init.split("var options = ")[1]?.split(/;\r?\n/)[0];
  assert.ok(options);
  assert.deepEqual(JSON.parse(options).swaggerDoc, spec);
  rows.push({
    scenario:
      "Served Swagger UI exposes the existing Phase 6 OpenAPI contracts",
    result: "PASS",
    status: ui.status,
  });
  for (const op of operations) {
    assert.ok((op.security ?? spec.security)?.length);
    const url = op.url.replace(
      /\{[^}]+\}/g,
      "00000000-0000-4000-8000-000000000000",
    );
    for (const token of [null, "invalid-phase6-token"]) {
      const response = await fetch(base + url, {
        method: op.method.toUpperCase(),
        headers: token ? { Authorization: `Bearer ${token}` } : {},
        signal: AbortSignal.timeout(15000),
      });
      assert.equal(response.status, 401);
      const declared = op.responses["401"];
      const schema = declared.$ref ? resolve(declared.$ref) : declared;
      check(
        schema.content?.["application/json"]?.schema,
        await response.json(),
      );
      rows.push({
        scenario: `${op.operationId}: ${token ? "invalid" : "missing"} authentication`,
        result: "PASS",
        status: 401,
      });
    }
  }
  rows.push({
    scenario:
      "Authenticated deletion/data reads, Firebase SMS, signup and password recovery success",
    result:
      "NOT RUN: no task-supplied disposable authenticated fixtures; no real accounts mutated",
  });
  const report = {
    checkedAt: new Date().toISOString(),
    mode: "OpenAPI / Swagger HTTP only; no data writes",
    rows,
  };
  fs.writeFileSync(
    path.resolve("../docs/audit/PHASE_6_OPENAPI_RESULTS.json"),
    JSON.stringify(report, null, 2) + "\n",
  );
  console.log(JSON.stringify(report, null, 2));
} finally {
  console.error = originalError;
  await new Promise<void>((done, reject) =>
    server.close((error) => (error ? reject(error) : done())),
  );
  await prisma.$disconnect();
}
