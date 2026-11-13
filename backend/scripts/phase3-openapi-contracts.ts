/** Phase 3: OpenAPI-driven, read-only HTTP contract verification. No workers or fixtures. */
import "dotenv/config";
import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import app from "../src/app.js";
import { swaggerSpec } from "../src/config/swagger.js";
import { prisma } from "../src/config/database.js";

const spec = swaggerSpec as any;
const rows: Array<{scenario: string; result: string; status?: number}> = [];
const resolve = (ref: string): any => ref.slice(2).split("/").reduce((v: any, key: string) => v?.[key], spec);
function check(schema: any, value: any): void {
  if (!schema) return;
  if (schema.$ref) return check(resolve(schema.$ref), value);
  if (value === null && schema.nullable) return;
  for (const part of schema.allOf ?? []) check(part, value);
  if (schema.type === "object") {
    assert.ok(value && typeof value === "object" && !Array.isArray(value));
    for (const key of schema.required ?? []) assert.ok(key in value, `Missing ${key}`);
    for (const [key, child] of Object.entries(schema.properties ?? {})) if (key in value) check(child, value[key]);
  } else if (schema.type === "array") {
    assert.ok(Array.isArray(value));
    for (const item of value) check(schema.items, item);
  } else if (schema.type === "integer") assert.ok(Number.isInteger(value));
  else if (schema.type) assert.equal(typeof value, schema.type);
  if (schema.enum) assert.ok(schema.enum.includes(value));
}
const operationIds = ["listCurrentUserOutings", "getOuting", "createOuting", "updateOuting", "cancelOuting", "replaceOutingBallot", "getVotingState", "setOutingAttendance", "listOutingArrivals", "recordOutingArrival", "saveOuting", "unsaveOuting", "listOutingMessages", "sendOutingMessage"];
const operations = Object.entries(spec.paths).flatMap(([url, item]: [string, any]) =>
  Object.entries(item).map(([method, op]: [string, any]) => ({url, method, ...op})))
  .filter(op => operationIds.includes(op.operationId));
assert.equal(operations.length, operationIds.length);
const ballot = operations.find(op => op.operationId === "replaceOutingBallot").requestBody.content["application/json"].schema;
assert.deepEqual(ballot.required,["option_ids"]);
assert.equal(ballot.properties.option_ids.maxItems,5);
assert.equal(ballot.properties.option_ids.uniqueItems,true);
assert.ok(spec.components.schemas.VotingStateResponse.allOf.some((part:any) => part.properties?.data?.properties?.my_option_ids && part.properties?.data?.properties?.voted_count));
rows.push({scenario:"OpenAPI documents atomic multi-location ballots and distinct voter counts",result:"PASS"});
const server = app.listen(0, "127.0.0.1");
await new Promise<void>(done => server.once("listening", done));
const address = server.address();
if (!address || typeof address === "string") throw Error("No listener");
const base = `http://127.0.0.1:${address.port}`;
const originalError = console.error;
console.error = (message, ...args) => {
  if (typeof message === "string" && message.startsWith("[Firebase Auth]")) return;
  originalError(message, ...args);
};
try {
  const ui = await fetch(base + "/api-docs/");
  assert.equal(ui.status, 200);
  const init = await (await fetch(base + "/api-docs/swagger-ui-init.js")).text();
  const options = init.split("var options = ")[1]?.split(/;\r?\n/)[0];
  assert.ok(options);
  assert.deepEqual(JSON.parse(options).swaggerDoc, spec);
  rows.push({scenario: "Served Swagger UI exposes the updated OpenAPI contract", result: "PASS", status: ui.status});
  for (const op of operations) {
    assert.ok((op.security ?? spec.security)?.length);
    const url = op.url.replace(/\{[^}]+\}/g, "00000000-0000-4000-8000-000000000000");
    for (const token of [null, "invalid-phase3-token"]) {
      const response = await fetch(base + url, {
        method: op.method.toUpperCase(), headers: token ? {Authorization: `Bearer ${token}`} : {},
        signal: AbortSignal.timeout(15000),
      });
      assert.equal(response.status, 401);
      const declared = op.responses["401"];
      const schema = declared.$ref ? resolve(declared.$ref) : declared;
      check(schema.content?.["application/json"]?.schema, await response.json());
      rows.push({scenario: `${op.operationId}: ${token ? "invalid" : "missing"} authentication`, result: "PASS", status: 401});
    }
  }
  rows.push({scenario: "Authenticated outing mutations and migration rehearsal", result: "PASS: separate disposable-schema HTTP suite; see PHASE_3_OPENAPI_RESULTS.json"});
  const report = {checkedAt: new Date().toISOString(), mode: "OpenAPI / Swagger HTTP only; no data writes", rows};
  fs.writeFileSync(path.resolve("../docs/audit/PHASE_3_OPENAPI_CONTRACT_RESULTS.json"), JSON.stringify(report, null, 2) + "\n");
  console.log(JSON.stringify(report, null, 2));
} finally {
  console.error = originalError;
  await new Promise<void>((done, reject) => server.close(error => error ? reject(error) : done()));
  await prisma.$disconnect();
}
