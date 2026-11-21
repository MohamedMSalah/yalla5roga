import { isolatedDatabase } from "./support/isolated-database.js";
import assert from "node:assert/strict";
import { randomUUID } from "node:crypto";
import { test } from "node:test";
import { responseAssertion, withApi, type OpenApi } from "./support/http-fixture.js";

const monitoringToken = "local-test-monitoring-credential";
process.env.MONITORING_TOKEN = monitoringToken;
process.env.OBSERVABILITY_ENABLED = "1";
process.env.OBS_MOBILE_TELEMETRY = "1";
const { default: app, routeInventory, swaggerCoverage } = await import("../src/app.js");
const { prisma } = await import("../src/config/database.js");

test("served Swagger and actual route registrations agree", async () => {
  await withApi(app, async base => {
    const response = await fetch(base + "/api-docs/openapi.json");
    assert.equal(response.status, 200);
    const spec = await response.json() as OpenApi;
    assert.ok(spec.paths["/api/groups/cuser"]?.get);
    assert.equal(swaggerCoverage.documentedApiRoutes, swaggerCoverage.apiRoutes - swaggerCoverage.optionalUndocumented.length);
    assert.deepEqual(swaggerCoverage.undocumented, []);
    assert.deepEqual(swaggerCoverage.unregistered, []);
    assert.equal(swaggerCoverage.duplicated, 0);
  });
});

test("production API operations enforce documented public and protected boundaries", async t => {
  await withApi(app, async base => {
    const spec = await (await fetch(base + "/api-docs/openapi.json")).json() as OpenApi;
    const id = "00000000-0000-4000-8000-000000000001";
    const publicCases: Record<string, { status: number; query?: string; db?: boolean }> = {
      "GET /": { status: 200 },
      "GET /health": { status: 200, db: true },
      "GET /api/places": { status: 200, query: "?limit=1", db: true },
      "GET /api/places/nearby": { status: 400 },
      "GET /api/places/{id}": { status: 404, db: true },
      "GET /api/places/{id}/hours": { status: 400 },
      "GET /api/places/{id}/images": { status: 400 },
      "GET /api/places/{id}/prices": { status: 400 },
      "GET /api/places/changes": { status: 400, query: "?cursor=invalid" },
      "GET /api/places/recommendations": { status: 400, query: "?limit=0" },
      "GET /api/places/geojson": { status: 400 },
      "GET /api/places/categories": { status: 200, db: true },
      "GET /api/places/vibes": { status: 200, db: true },
      "GET /api/places/version": { status: 200, db: true },
      "GET /api/places/licenses": { status: 200 },
      "GET /api/place-brands/{id}": { status: 400 },
      "GET /api/place-brands/{id}/branches": { status: 400 },
      "POST /api/auth/login": { status: 400 },
      "POST /api/auth/signup": { status: 400 },
      "POST /api/auth/recovery/start": { status: 400 },
      "POST /api/auth/recovery/verify": { status: 400 },
      "POST /api/auth/recovery/reset": { status: 400 },
    };
    for (const [path, operations] of Object.entries(spec.paths)) {
      if (!(path.startsWith("/api/") || path === "/" || path === "/health")) continue;
      for (const [verb, operation] of Object.entries(operations)) {
        if (!operation.responses) continue;
        const method = verb.toUpperCase();
        const key = `${method} ${path}`;
        const scenario = operation.security?.length === 0 ? publicCases[key] : { status: 401 };
        assert.ok(scenario, `No public test case for ${key}`);
        await t.test(key, { skip: scenario.db && !isolatedDatabase }, async () => {
          const invalidParam = scenario.status === 400 ? "invalid-id" : id;
          const url = path.replace(/\{\w+\}/g, invalidParam) + (scenario.query ?? "");
          const response = await fetch(base + url, {
            method,
            headers: { "Content-Type": "application/json" },
            body: method === "GET" ? undefined : "{}",
          });
          const payload = await response.json();
          assert.equal(response.status, scenario.status);
          assert.equal(payload.success, response.ok);
          assert.match(response.headers.get("server-timing") ?? "", /app;dur=\d/);
          assert.match(response.headers.get("x-request-id") ?? "", /^[a-f0-9-]{36}$/);
          responseAssertion(spec, operation, response.status, response.headers.get("content-type")?.split(";")[0] ?? "", payload);
        });
      }
    }
  });
  await prisma.$disconnect();
});

test("private metrics and telemetry reject unauthenticated callers, and labels stay bounded", async () => {
  await withApi(app, async base => {
    const id = randomUUID();
    const correlation = randomUUID();
    const response = await fetch(base + "/api/places/licenses?test_private_value=xyz", {
      headers: { "X-Request-ID": id, "X-Correlation-ID": correlation, "X-Client-Source": "flutter" },
    });
    assert.equal(response.headers.get("x-request-id"), id);
    assert.equal(response.headers.get("x-correlation-id"), correlation);
    assert.equal(response.headers.get("x-route-template"), "/api/places/licenses");
    await response.arrayBuffer();
    const live = await fetch(base + "/health/live");
    assert.equal(live.status, 200);
    assert.deepEqual(await live.json(), { success: true, status: "live" });
    const readiness = await fetch(base + "/health/ready");
    assert.equal(readiness.status, 503);
    assert.deepEqual(await readiness.json(), { success: false, status: "unavailable" });
    for (const path of ["/health/dependencies", "/metrics"]) {
      assert.equal((await fetch(base + path)).status, 401);
    }
    assert.equal((await fetch(base + "/monitoring/mobile", { method: "POST" })).status, 401);
    const headers = { Authorization: `Bearer ${monitoringToken}` };
    const metrics = await fetch(base + "/metrics", { headers });
    assert.equal(metrics.status, 200);
    const payload = await metrics.text();
    assert.match(payload, /yalla_http_duration_seconds_bucket/);
    assert.match(payload, /endpoint="\/api\/places\/licenses"/);
    for (const literal of [id, correlation, "test_private_value", "xyz", monitoringToken]) {
      assert.ok(!payload.includes(literal));
    }
    const dependencies = await (await fetch(base + "/health/dependencies", { headers })).json();
    assert.equal(dependencies.success, true);
    assert.ok(dependencies.database && dependencies.dependencies && dependencies.jobs);
    assert.ok(routeInventory.some(route => route.path === "/monitoring/mobile"));
  });
});
