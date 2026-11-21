import express, { type Application, type RequestHandler } from "express";
import { performance } from "node:perf_hooks";
import { z } from "zod";
import { authMiddleware } from "../middleware/auth.middleware.js";
import { enabled } from "./config.js";
import { increment, observe } from "./metrics.js";
import type { registeredRoutes } from "./routes.js";

export const mobileTelemetryEnabled = enabled && process.env.OBS_MOBILE_TELEMETRY === "1";
const entry = z.object({
  method: z.enum(["GET", "POST", "PATCH", "PUT", "DELETE", "HEAD"]),
  endpoint: z.string().max(100),
  clientMs: z.number().finite().nonnegative().max(120000),
  serverMs: z.number().finite().nonnegative().max(120000).optional(),
  status: z.union([z.number().int().min(100).max(599), z.literal(0)]),
  cache: z.enum(["hit", "miss", "stale"]).optional(),
}).strict();
const body = z.array(entry).min(1).max(12);
const accounts = new Map<string, { count: number; until: number }>();
const limit: RequestHandler = (req, res, next) => {
  const uid = req.user!.uid;
  const now = performance.now();
  let bucket = accounts.get(uid);
  if (!bucket || bucket.until <= now) {
    if (accounts.size >= 2048) {
      for (const [key, value] of accounts) if (value.until <= now) accounts.delete(key);
    }
    if (accounts.size >= 2048 && !accounts.has(uid)) {
      res.sendStatus(429);
      return;
    }
    bucket = { count: 0, until: now + 60000 };
    accounts.set(uid, bucket);
  }
  if (++bucket.count > 4) { res.sendStatus(429); return; }
  next();
};

export function installMobileTelemetry(app: Application, routes: () => ReturnType<typeof registeredRoutes>) {
  if (!mobileTelemetryEnabled) return;
  let allowed: Set<string> | undefined;
  app.post("/monitoring/mobile", authMiddleware, limit, express.json({ limit: "6kb" }), (req, res) => {
    const result = body.safeParse(req.body);
    allowed ??= new Set(routes().filter(route => route.path.startsWith("/api/") && !route.path.includes("/mock-"))
      .map(route => `${route.method} ${route.path}`));
    if (!result.success || result.data.some(item => !allowed!.has(`${item.method} ${item.endpoint}`))) {
      res.status(400).json({ success: false, message: "Invalid telemetry batch" });
      return;
    }
    for (const item of result.data) {
      const labels = { method: item.method, endpoint: item.endpoint, status: String(item.status) };
      observe("mobile_duration_seconds", item.clientMs / 1000, labels);
      if (item.serverMs !== undefined) observe("mobile_server_header_seconds", item.serverMs / 1000, labels);
      if (item.cache) increment("cache_operations_total", { layer: "mobile_sample", status: item.cache });
    }
    res.status(204).end();
  });
}
