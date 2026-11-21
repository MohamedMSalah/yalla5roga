import "./support/isolated-database.js";
import assert from "node:assert/strict";
import { once, EventEmitter } from "node:events";
import { randomUUID } from "node:crypto";
import { setTimeout as delay } from "node:timers/promises";
import { test } from "node:test";
import express from "express";
import { requestMonitoring, observeRequestIdentity } from "../src/monitoring/http.js";
import { currentRequest } from "../src/monitoring/context.js";
import { metricsText } from "../src/monitoring/metrics.js";
import { registeredRoutes } from "../src/monitoring/routes.js";
import { withApi } from "./support/http-fixture.js";

test("concurrent requests retain separate context, and aborted responses finalize once", async () => {
  const app = express();
  app.use(requestMonitoring(() => routes));
  app.use(observeRequestIdentity);
  const emitter = new EventEmitter();
  app.get("/api/observability-test/:id", (req, res) => {
    if (req.params.id === "cancel") {
      emitter.emit("started");
      res.once("close", () => emitter.emit("closed"));
      return;
    }
    return delay(30).then(() => {
      res.json({ id: currentRequest()?.requestId });
    });
  });
  const routes = registeredRoutes(app);

  await withApi(app, async base => {
    const ids = [randomUUID(), randomUUID(), randomUUID()];
    const rows = await Promise.all(ids.map(id => fetch(base + "/api/observability-test/same?limit=20",
      { headers: { "X-Request-ID": id, "X-Request-Trigger": "initial_load" } }).then(response => response.json())));
    assert.deepEqual(rows.map(row => row.id), ids);
    const controller = new AbortController();
    const started = once(emitter, "started");
    const closed = once(emitter, "closed");
    const pending = fetch(base + "/api/observability-test/cancel", { signal: controller.signal });
    const aborted = assert.rejects(pending, { name: "AbortError" });
    await started;
    controller.abort();
    await aborted;
    await closed;
    const metrics = metricsText();
    assert.match(metrics, /yalla_http_requests_total\{[^\n]*endpoint="\/api\/observability-test\/:id",status="200"\} 3\n/);
    assert.match(metrics, /yalla_http_requests_total\{[^\n]*endpoint="\/api\/observability-test\/:id",status="aborted"\} 1\n/);
    assert.match(metrics, /yalla_http_potential_duplicates_total\{[^\n]*trigger="initial_load"\} [12]\n/);
    assert.match(metrics, /yalla_http_active\{[^\n]*\} 0\n/);
    for (const id of ids) assert.ok(!metrics.includes(id));
  });
});
