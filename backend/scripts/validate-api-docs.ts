import "dotenv/config";
import assert from "node:assert/strict";
import { readdirSync, readFileSync } from "node:fs";
import { swaggerSpec } from "../src/config/swagger.js";
import app from "../src/app.js";

type Layer = {
  route?: { path: string; methods: Record<string, boolean> };
  handle?: { stack?: Layer[] };
  matchers?: Array<(path: string) => unknown>;
};
type Operation = {
  operationId: string;
  tags: string[];
  responses: Record<string, object>;
};
const spec = swaggerSpec as {
  tags: Array<{ name: string }>;
  paths: Record<string, Record<string, Operation>>;
};
const mountCandidates = readdirSync(new URL("../src/routes/", import.meta.url), {
  recursive: true,
  encoding: "utf-8",
}).filter(file => file.endsWith(".ts")).flatMap(file => [
  ...readFileSync(new URL("../src/routes/" + file.replaceAll("\\", "/"), import.meta.url), "utf8")
    .matchAll(/\.use\("(\/api\/[^"/]+)"/g),
].map(match => match[1]));
const mounts = [...new Set(mountCandidates)];

function collectRoutes(stack: Layer[], prefix = ""): string[] {
  const operations: string[] = [];
  for (const layer of stack) {
    if (layer.route) {
      const routePath = layer.route.path === "/" && prefix ? prefix : prefix + layer.route.path;
      const template = routePath.replace(/:(\w+)/g, "{$1}");
      for (const [method, enabled] of Object.entries(layer.route.methods)) {
        if (enabled) operations.push(method.toUpperCase() + " " + template);
      }
    } else if (layer.handle?.stack) {
      // Express 5 leaves the matched mount on the request. A root mount
      // matches "/", while a feature mount only matches its own prefix.
      const matches = (path: string) => layer.matchers?.some(match => match(path));
      const mount = matches("/") ? "" : mounts.find(matches);
      assert.notEqual(mount, undefined, "Express mount has no source prefix");
      operations.push(...collectRoutes(layer.handle.stack, prefix + mount));
    }
  }
  return operations;
}

const registered = collectRoutes(app.router.stack as unknown as Layer[]);
const documented = Object.entries(spec.paths).flatMap(([path, methods]) =>
  Object.entries(methods).map(([method, operation]) => ({
    key: method.toUpperCase() + " " + path, operation,
  })),
);
const tags = new Set(spec.tags.map(tag => tag.name));
const ids = new Set<string>();
for (const { key, operation } of documented) {
  assert.ok(operation.operationId && !ids.has(operation.operationId), key + " requires a unique operationId");
  ids.add(operation.operationId);
  assert.ok(operation.tags?.length && operation.tags.every(tag => tags.has(tag)), key + " has an unknown tag");
  assert.ok(Object.keys(operation.responses ?? {}).length, key + " requires a response contract");
}
function verifyReferences(value: unknown) {
  if (!value || typeof value !== "object") return;
  for (const [key, item] of Object.entries(value)) {
    if (key === "$ref" && typeof item === "string" && item.startsWith("#/")) {
      const target = item.slice(2).split("/").reduce<unknown>((parent, segment) =>
        (parent as Record<string, unknown> | undefined)?.[segment], spec);
      assert.ok(target, "Unresolved OpenAPI reference " + item);
    } else {
      verifyReferences(item);
    }
  }
}
verifyReferences(spec);
assert.deepEqual(registered.sort(), documented.map(row => row.key).sort());
console.log("Express and OpenAPI match for " + registered.length + " operations, with unique IDs and valid local references.");
