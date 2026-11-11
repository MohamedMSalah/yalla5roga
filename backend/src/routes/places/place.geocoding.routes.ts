import { Router } from "express";
import { authMiddleware } from "../../middleware/auth.middleware.js";
import { configuredGeocodingProvider, geocodingRequest } from "../../services/places/geocoding.js";

const router = Router();
const provider = configuredGeocodingProvider();
const configuredRate = Number(process.env.GEOCODING_REQUESTS_PER_MINUTE);
const requestsPerMinute = Number.isSafeInteger(configuredRate) && configuredRate > 0
  ? configuredRate
  : 60;
// One upstream budget per process. Deployments with replicas must also enforce
// the aggregate provider quota at their gateway.
const upstreamRequests: number[] = [];

/**
 * @openapi
 * /api/places/geocoding:
 *   post:
 *     tags: [Places]
 *     summary: Search or reverse geocode a map location
 *     description: Uses the configured geocoding provider. When disabled, returns an empty result with available set to false.
 *     operationId: geocodePlace
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             oneOf:
 *               - type: object
 *                 required: [kind, query, language]
 *                 properties:
 *                   kind: { type: string, enum: [search] }
 *                   query: { type: string, minLength: 2, maxLength: 120 }
 *                   language: { type: string, enum: [en, ar] }
 *               - type: object
 *                 required: [kind, latitude, longitude, language]
 *                 properties:
 *                   kind: { type: string, enum: [reverse] }
 *                   latitude: { type: number, minimum: -90, maximum: 90 }
 *                   longitude: { type: number, minimum: -180, maximum: 180 }
 *                   language: { type: string, enum: [en, ar] }
 *     responses:
 *       "200":
 *         description: Geocoding results and provider availability
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               required: [success, data]
 *               properties:
 *                 success: { type: boolean }
 *                 data:
 *                   type: object
 *                   required: [available, results]
 *                   properties:
 *                     available: { type: boolean }
 *                     attribution: { type: string }
 *                     cache_seconds: { type: integer, minimum: 0, maximum: 300 }
 *                     results:
 *                       type: array
 *                       items:
 *                         type: object
 *                         required: [id, name, area, latitude, longitude]
 *                         properties:
 *                           id: { type: string }
 *                           name: { type: string }
 *                           area: { type: string }
 *                           latitude: { type: number }
 *                           longitude: { type: number }
 *       "400":
 *         $ref: "#/components/responses/BadRequest"
 *       "401":
 *         $ref: "#/components/responses/Unauthorized"
 *       "429":
 *         description: Geocoding quota reached
 *         headers:
 *           Retry-After:
 *             schema: { type: integer, minimum: 1 }
 *         content:
 *           application/json:
 *             schema:
 *               $ref: "#/components/schemas/ErrorResponse"
 *       "502":
 *         description: Geocoding provider unavailable
 *         content:
 *           application/json:
 *             schema:
 *               $ref: "#/components/schemas/ErrorResponse"
 */
router.post("/geocoding", authMiddleware, async (req, res) => {
  res.set("Cache-Control", "no-store");
  const parsed = geocodingRequest.safeParse(req.body);
  if (!parsed.success) {
    res.status(400).json({ success: false, message: "Invalid geocoding request" });
    return;
  }
  if (!provider) {
    res.json({ success: true, data: { available: false, results: [] } });
    return;
  }
  const now = Date.now();
  while (upstreamRequests.length && upstreamRequests[0]! <= now - 60_000) upstreamRequests.shift();
  if (upstreamRequests.length >= requestsPerMinute) {
    res.set("Retry-After", String(Math.max(1, Math.ceil((upstreamRequests[0]! + 60_000 - now) / 1000))));
    res.status(429).json({ success: false, message: "Geocoding quota reached" });
    return;
  }
  upstreamRequests.push(now);
  const disconnect = new AbortController();
  const onClose = () => disconnect.abort();
  res.once("close", onClose);
  try {
    const signal = AbortSignal.any([disconnect.signal, AbortSignal.timeout(5000)]);
    const results = await provider.lookup(parsed.data, signal);
    if (!res.destroyed) res.json({
      success: true,
      data: { available: true, results, attribution: provider.attribution, cache_seconds: provider.cacheSeconds },
    });
  } catch {
    if (!res.destroyed) res.status(502).json({ success: false, message: "Geocoding unavailable" });
  } finally {
    res.off("close", onClose);
  }
});

export default router;
