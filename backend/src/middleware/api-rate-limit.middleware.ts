import type { RequestHandler } from "express";
import { isolatedTestTarget } from "../monitoring/config.js";

// Bounded single-process fixed windows, keyed by Express's trusted client IP.
const buckets = new Map<string, { count: number; reset: number }>();
const limit = isolatedTestTarget ? 60_000 : 300;
let pruneAt = 0;
export const apiRateLimit: RequestHandler = (req, res, next) => {
  const now = Date.now();
  const key = req.ip ?? req.socket.remoteAddress ?? "unknown";
  if (now >= pruneAt) {
    for (const [ip, bucket] of buckets) if (bucket.reset <= now) buckets.delete(ip);
    pruneAt = now + 5000;
  }
  let bucket = buckets.get(key);
  if (!bucket || bucket.reset <= now) {
    if (bucket) buckets.delete(key);
    if (buckets.size >= 10000) {
      res.setHeader("Retry-After", "60");
      res.status(429).json({ success: false, message: "Too many requests. Try again later." });
      return;
    }
    bucket = { count: 0, reset: now + 60000 };
    buckets.set(key, bucket);
  }
  if (++bucket.count > limit) {
    res.setHeader("Retry-After", String(Math.max(1, Math.ceil((bucket.reset - now) / 1000))));
    res.status(429).json({ success: false, message: "Too many requests. Try again later." });
    return;
  }
  next();
};
