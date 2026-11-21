import { createHmac, randomBytes } from "node:crypto";
import { performance } from "node:perf_hooks";
import type { Request } from "express";
import { duplicateWindowMs, enabled } from "./config.js";

const secret = randomBytes(32);
const history = new Map<string, { start: number; count: number; active: number }>();
const intentional = new Set(["manual_refresh", "pagination", "viewport_changed", "search", "retry"]);

export function startDuplicateCheck(req: Request, route: string, trigger: string) {
  if (!enabled || !route.startsWith("/api/") || intentional.has(trigger)) return;
  const read = req.method === "GET" || req.method === "HEAD";
  if (!read && !(req.method === "POST" && route === "/api/users/sync")) return;
  // Session/target values live only inside a keyed, ephemeral digest.
  if (req.originalUrl.length > 4096) return;
  const parsed = new URL(req.originalUrl, "http://localhost");
  parsed.searchParams.sort();
  const body = read ? "" : JSON.stringify(req.body ?? null);
  if (body.length > 8192) return;
  const scope = req.get("Authorization") || req.ip || "anonymous";
  const key = createHmac("sha256", secret)
    .update(JSON.stringify([scope, req.method, route, parsed.pathname, parsed.search, trigger, body]))
    .digest("base64url");
  const now = performance.now();
  let entry = history.get(key);
  if (!entry || (entry.active === 0 && now - entry.start >= duplicateWindowMs)) {
    history.delete(key);
    if (history.size >= 2048) history.delete(history.keys().next().value!);
    entry = { start: now, count: 0, active: 0 };
    history.set(key, entry);
  }
  entry.active++;
  entry.count++;
  const occurrences = entry.count;
  const concurrent = entry.active;
  const suspicious = concurrent === 2 || (occurrences === 3 && now - entry.start < duplicateWindowMs);
  return {
    end: () => { entry.active--; },
    duplicate: suspicious ? { occurrences, concurrent, windowMs: duplicateWindowMs } : undefined,
  };
}
