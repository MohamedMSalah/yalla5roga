import type { RequestHandler } from "express";
import { UnauthorizedError } from "../utils/errors.js";

// The API runs in one process. The shared IP limiter also applies to every route.
export function limitPlaceReviewActions(max: number): RequestHandler {
  const windowMs = 60 * 60 * 1000;
  const buckets = new Map<string, { count: number; expiresAt: number }>();
  let pruneAt = 0;
  return (req, res, next) => {
    const uid = req.user?.uid;
    if (!uid) return next(new UnauthorizedError());
    const now = Date.now();
    if (now >= pruneAt) {
      for (const [key, bucket] of buckets) {
        if (bucket.expiresAt <= now) buckets.delete(key);
      }
      pruneAt = now + 60_000;
    }
    let bucket = buckets.get(uid);
    if (!bucket || bucket.expiresAt <= now) {
      bucket = { count: 0, expiresAt: now + windowMs };
      // Keep memory bounded without resetting active accounts' budgets.
      if (buckets.size < 25_000 || buckets.has(uid)) buckets.set(uid, bucket);
      else bucket.count = max;
    }
    if (++bucket.count <= max) return next();
    res.set("Retry-After", String(Math.ceil((bucket.expiresAt - now) / 1000)));
    res.status(429).json({ success: false, message: "Too many requests. Try again later." });
  };
}
