import { timingSafeEqual } from "node:crypto";
import { performance } from "node:perf_hooks";
import type { Application, RequestHandler } from "express";
import { prisma } from "../config/database.js";
import { enabled, environment, healthTtlMs, isolatedTestTarget } from "./config.js";
import { jobHealth } from "./jobs.js";
import { collect, metricsText } from "./metrics.js";

type State = "pending" | "ready" | "degraded" | "disabled" | "failed" | "stopping";
const dependencies: Record<string, State> = {};
export function setDependency(name: string, state: State) { dependencies[name] = state; }
export function dependencyState(name: string) { return dependencies[name] ?? "disabled"; }

type Probe = { available: boolean; latencyMs?: number; checkedAt?: string };
let last: Probe = { available: false };
let expires = 0;
let checking: Promise<Probe> | undefined;

export function databaseHealth(force = false): Promise<Probe> {
  if (checking) return checking;
  if (!force && performance.now() < expires) return Promise.resolve(last);
  const start = performance.now();
  const probe = async () => {
    try {
      await prisma.$queryRaw`SELECT 1`;
      return { available: true, latencyMs: performance.now() - start };
    } catch {
      return { available: false };
    }
  };
  checking = probe().then(result => {
    last = { ...result, checkedAt: new Date().toISOString() };
    expires = performance.now() + healthTtlMs;
    return last;
  }).finally(() => { checking = undefined; });
  return checking;
}

const token = process.env.MONITORING_TOKEN;
export const privateMonitoringAvailable = enabled && Boolean(token && token.length >= 24);
const authorize: RequestHandler = (req, res, next) => {
  if (!privateMonitoringAvailable || !token) {
    res.status(404).json({ success: false, message: "Route not found" });
    return;
  }
  const value = Buffer.from(req.get("Authorization") ?? "");
  const expected = Buffer.from(`Bearer ${token}`);
  if (value.length !== expected.length || !timingSafeEqual(value, expected)) {
    res.status(401).json({ success: false, message: "Unauthorized" });
    return;
  }
  res.set("Cache-Control", "no-store");
  next();
};

collect("dependencies", () => ({
  db_available: Number(last.available),
  db_sample_age_seconds: last.checkedAt ? Math.max(0, (Date.now() - Date.parse(last.checkedAt)) / 1000) : -1,
  ...(last.latencyMs === undefined ? {} : { db_probe_seconds: last.latencyMs / 1000 }),
}));

export function installHealth(app: Application) {
  app.get("/health/live", (_req, res) => {
    res.set("Cache-Control", "no-store").json({ success: true, status: "live" });
  });
  app.get("/health/ready", async (_req, res) => {
    const runtimeReady = dependencies.server === "ready" && dependencies.firebase === "ready" &&
      dependencies.firebase_client === "ready" && dependencies.socket === "ready" &&
      dependencies.jobs === "ready" &&
      (environment !== "production" || dependencies.r2_private === "ready");
    // Bound the HTTP wait without issuing a second query while the probe is pending.
    const dbReady = runtimeReady && await new Promise<boolean>(resolve => {
      const timeout = setTimeout(() => resolve(false), 2500);
      void databaseHealth().then(result => {
        clearTimeout(timeout);
        resolve(result.available);
      });
    });
    res.set("Cache-Control", "no-store").status(dbReady ? 200 : 503)
      .json({ success: dbReady, status: dbReady ? "ready" : "unavailable" });
  });
  app.get("/health/dependencies", authorize, (_req, res) => {
    res.json({ success: true, database: last, dependencies: { ...dependencies }, jobs: jobHealth(), isolatedTestTarget });
  });
  app.get("/metrics", authorize, (_req, res) => {
    res.set("Content-Type", "text/plain; version=0.0.4; charset=utf-8").send(metricsText());
  });
}
