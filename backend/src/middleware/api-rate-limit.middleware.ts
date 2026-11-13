import type { RequestHandler } from "express";

// Bounded single-process fixed windows, keyed by Express's trusted client IP.
const buckets = new Map<string, { count: number; reset: number }>();
export const apiRateLimit: RequestHandler = (req, res, next) => {
  const now = Date.now();
  const key = req.ip ?? req.socket.remoteAddress ?? "unknown";
  for (const [ip, bucket] of buckets) if (bucket.reset <= now) buckets.delete(ip);
  let bucket = buckets.get(key);
  if (!bucket) {
    if (buckets.size >= 10000) {
      res.setHeader("Retry-After", "60");
      res.status(429).json({ success: false, message: "Too many requests. Try again later." });
      return;
    }
    bucket = { count: 0, reset: now + 60000 };
    buckets.set(key, bucket);
  }
  if (++bucket.count > 300) {
    res.setHeader("Retry-After", String(Math.max(1, Math.ceil((bucket.reset - now) / 1000))));
    res.status(429).json({ success: false, message: "Too many requests. Try again later." });
    return;
  }
  next();
};
