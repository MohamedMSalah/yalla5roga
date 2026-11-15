/** Served Swagger/OpenAPI audit: no accounts, database queries, jobs or sockets. */
import assert from "node:assert/strict";
import { writeFileSync } from "node:fs";

// Never point this verification process at application data or start dev pings.
process.env.NODE_ENV = "production";
process.env.DATABASE_URL = "postgresql://audit:audit@127.0.0.1:1/unreachable";
// Load adapter configuration before app/spec construction, just as server.ts
// does. dotenv does not override the unreachable verification database above.
await import("dotenv/config");

const { default: app } = await import("../src/app.js");
const { swaggerSpec } = await import("../src/config/swagger.js");
const { prisma } = await import("../src/config/database.js");

type Schema = {
  $ref?: string;
  type?: string;
  nullable?: boolean;
  required?: string[];
  properties?: Record<string, Schema>;
  items?: Schema;
  allOf?: Schema[];
  enum?: unknown[];
};
type ResponseContract = {
  $ref?: string;
  content?: Record<string, { schema?: Schema }>;
};
type Operation = {
  operationId: string;
  security?: Array<Record<string, unknown>>;
  responses: Record<string, ResponseContract>;
};
const spec = swaggerSpec as unknown as {
  security?: Array<Record<string, unknown>>;
  paths: Record<string, Record<string, Operation>>;
};
const rows: Array<{ scenario: string; status: "PASS" | "NOT RUN"; httpStatus?: number }> = [];
function resolve<T>(ref: string): T {
  assert.ok(ref.startsWith("#/"), `Nonlocal reference: ${ref}`);
  return ref.slice(2).split("/").reduce<unknown>(
    (parent, key) => (parent as Record<string, unknown>)?.[key], spec,
  ) as T;
}
function check(schema: Schema | undefined, value: unknown): void {
  if (!schema) return;
  if (schema.$ref) return check(resolve<Schema>(schema.$ref), value);
  if (value === null && schema.nullable) return;
  for (const child of schema.allOf ?? []) check(child, value);
  if (schema.type === "object") {
    assert.ok(value && typeof value === "object" && !Array.isArray(value));
    const object = value as Record<string, unknown>;
    for (const key of schema.required ?? []) assert.ok(key in object, key);
    for (const [key, child] of Object.entries(schema.properties ?? {})) {
      if (key in object) check(child, object[key]);
    }
  } else if (schema.type === "array") {
    assert.ok(Array.isArray(value));
    for (const item of value) check(schema.items, item);
  } else if (schema.type === "integer") assert.ok(Number.isInteger(value));
  else if (schema.type) assert.equal(typeof value, schema.type);
  if (schema.enum) assert.ok(schema.enum.includes(value));
}
const methods = new Set(["get", "post", "put", "patch", "delete"]);
const operations = Object.entries(spec.paths).flatMap(([path, item]) =>
  Object.entries(item).filter(([method]) => methods.has(method))
    .map(([method, operation]) => ({ path, method, ...operation })),
);
const protectedOperations = operations.filter(
  (op) => (op.security ?? spec.security ?? []).some((requirement) => Object.keys(requirement).length > 0),
);
// Stay below the real API limiter; do not disable production middleware.
assert.ok(protectedOperations.length * 2 < 300);
const server = app.listen(0, "127.0.0.1");
await new Promise<void>((done) => server.once("listening", done));
const address = server.address();
assert.ok(address && typeof address !== "string");
const base = `http://127.0.0.1:${address.port}`;
const originalError = console.error;
console.error = (message: unknown, ...args: unknown[]) => {
  if (typeof message === "string" && message.startsWith("[Firebase Admin]")) return;
  originalError(message, ...args);
};
try {
  // Reuse the existing source route/OpenAPI parity and local-reference validator.
  await import("./validate-api-docs.js");
  rows.push({ scenario: "Express routes match OpenAPI; unique operation IDs and valid references", status: "PASS" });
  const ui = await fetch(`${base}/api-docs/`, { signal: AbortSignal.timeout(15000) });
  assert.equal(ui.status, 200);
  const init = await fetch(`${base}/api-docs/swagger-ui-init.js`, { signal: AbortSignal.timeout(15000) });
  assert.equal(init.status, 200);
  const options = (await init.text()).split("var options = ")[1]?.split(/;\r?\n/)[0];
  assert.ok(options);
  assert.deepEqual(JSON.parse(options).swaggerDoc, spec);
  rows.push({ scenario: "Served Swagger UI contains the audited contracts", status: "PASS", httpStatus: 200 });
  for (const op of protectedOperations) {
    const url = op.path.replace(/\{[^}]+\}/g, "00000000-0000-4000-8000-000000000000");
    for (const invalidToken of [false, true]) {
      const response = await fetch(base + url, {
        method: op.method.toUpperCase(),
        headers: invalidToken ? { Authorization: "Bearer invalid-phase7-token" } : {},
        signal: AbortSignal.timeout(15000),
      });
      assert.equal(response.status, 401, `${op.operationId}: auth boundary`);
      let contract = op.responses["401"];
      assert.ok(contract, `${op.operationId}: declared 401 response`);
      if (contract.$ref) contract = resolve<ResponseContract>(contract.$ref);
      const schema = contract.content?.["application/json"]?.schema;
      assert.ok(schema, `${op.operationId}: declared JSON error schema`);
      check(schema, await response.json());
      rows.push({ scenario: `${op.operationId}: ${invalidToken ? "invalid" : "missing"} authentication`, status: "PASS", httpStatus: 401 });
    }
  }
  rows.push({ scenario: "Authenticated mutations/reads, live Socket.IO, FCM, deep-link lifecycle, cache/visual/device behavior", status: "NOT RUN" });
  const report = {
    checkedAt: new Date().toISOString(),
    mode: "Local served Swagger/OpenAPI HTTP only; unreachable database target; configured auth adapter, no workers or authenticated fixtures",
    documentedOperations: operations.length,
    protectedOperations: protectedOperations.length,
    passed: rows.filter((row) => row.status === "PASS").length,
    rows,
  };
  writeFileSync(new URL("../../docs/audit/PHASE_7_OPENAPI_RESULTS.json", import.meta.url), JSON.stringify(report, null, 2) + "\n");
  console.log(JSON.stringify({ passed: report.passed, documentedOperations: operations.length, protectedOperations: protectedOperations.length }));
} finally {
  console.error = originalError;
  server.closeAllConnections();
  await new Promise<void>((done, reject) => server.close((error) => error ? reject(error) : done()));
  await prisma.$disconnect();
}
