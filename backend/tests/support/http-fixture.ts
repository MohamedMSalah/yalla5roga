import assert from "node:assert/strict";
import { once } from "node:events";
import type { Application } from "express";
import type { Server } from "node:http";

export async function withApi(
  app: Application,
  use: (url: string, server: Server) => Promise<void>,
) {
  const server = app.listen(0, "127.0.0.1");
  try {
    await once(server, "listening");
    const address = server.address();
    assert.ok(address && typeof address !== "string");
    await use(`http://127.0.0.1:${address.port}`, server);
  } finally {
    server.closeAllConnections();
    if (server.listening) await new Promise<void>(resolve => server.close(() => resolve()));
  }
}

type Schema = {
  $ref?: string; nullable?: boolean; type?: string; enum?: unknown[];
  required?: string[]; properties?: Record<string, Schema>; items?: Schema;
  allOf?: Schema[]; oneOf?: Schema[]; anyOf?: Schema[];
};
type ResponseDoc = { $ref?: string; content?: Record<string, { schema?: Schema }> };
export type Operation = { security?: unknown[]; responses: Record<string, ResponseDoc> };
export type OpenApi = { paths: Record<string, Record<string, Operation>> };

export function responseAssertion(spec: OpenApi, operation: Operation, status: number, contentType: string, payload: unknown) {
  const ref = <T>(value: string): T => value.slice(2).split("/").reduce<unknown>((target, part) =>
    (target as Record<string, unknown>)[part], spec) as T;
  const check = (schema: Schema, data: unknown, label: string): void => {
    if (schema.$ref) return check(ref<Schema>(schema.$ref), data, label);
    if (schema.nullable && data === null) return;
    if (schema.enum) assert.ok(schema.enum.includes(data), `Invalid enum at ${label}`);
    for (const part of schema.allOf ?? []) check(part, data, label);
    const alternatives = schema.oneOf ?? schema.anyOf;
    if (alternatives) {
      const matches = alternatives.filter(part => {
        try { check(part, data, label); return true; } catch { return false; }
      }).length;
      assert.ok(schema.oneOf ? matches === 1 : matches > 0, `No valid alternative at ${label}`);
    }
    if (schema.type === "object") {
      assert.ok(data && typeof data === "object" && !Array.isArray(data), `Expected object at ${label}`);
      const fields = data as Record<string, unknown>;
      for (const key of schema.required ?? []) assert.ok(Object.hasOwn(fields, key), `Missing ${label}.${key}`);
      for (const [key, part] of Object.entries(schema.properties ?? {})) {
        if (Object.hasOwn(fields, key)) check(part, fields[key], `${label}.${key}`);
      }
    } else if (schema.type === "array") {
      assert.ok(Array.isArray(data), `Expected array at ${label}`);
      if (schema.items) for (const item of data) check(schema.items, item, `${label}[]`);
    } else if (schema.type === "integer") {
      assert.ok(Number.isInteger(data), `Expected integer at ${label}`);
    } else if (schema.type) {
      assert.equal(typeof data, schema.type, `Wrong type at ${label}`);
    }
  };
  const documented = operation.responses[status];
  assert.ok(documented, `Missing response ${status} in Swagger`);
  const response = documented.$ref ? ref<ResponseDoc>(documented.$ref) : documented;
  if (response.content) assert.ok(response.content[contentType], `Unexpected documented content type ${contentType}`);
  const schema = response.content?.[contentType]?.schema;
  if (schema) check(schema, payload, "$");
}
