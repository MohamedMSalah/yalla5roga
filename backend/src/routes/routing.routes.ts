import { Router } from "express";
import { z } from "zod";
import { ownerResponse } from "../controllers/users/saved-location.controller.js";
import { authMiddleware } from "../middleware/auth.middleware.js";
import { validate } from "../middleware/validate.middleware.js";
import { GetMyMeetupRouteUseCase, GetMyOutingRouteUseCase } from "../usecases/routing/route-preview.usecases.js";
import { routingCapabilities } from "../types/users/transportation.types.js";

const router = Router();

router.get("/api/routing/capabilities", (_req, res) => {
  res.json({ success: true, data: routingCapabilities });
});


const meetup = new GetMyMeetupRouteUseCase();
const outing = new GetMyOutingRouteUseCase();
const empty = z.strictObject({}).optional();

router.get("/api/smart-meetups/:sessionId/recommendations/:placeId/my-route", authMiddleware, validate({
  params: z.object({ sessionId: z.uuid(), placeId: z.uuid() }),
  body: empty,
  query: z.strictObject({ calculation_id: z.uuid(), input_version: z.string().regex(/^[1-9]\d*$/).refine(value =>
    Number.isSafeInteger(Number(value))) }),
}), ownerResponse((uid, req) => meetup.execute(uid, String(req.params.sessionId).toLowerCase(),
  String(req.params.placeId).toLowerCase(), String(req.query.calculation_id).toLowerCase(), Number(req.query.input_version))));

router.get("/api/outings/:outingId/my-route", authMiddleware, validate({
  params: z.object({ outingId: z.uuid() }), body: empty, query: empty,
}), ownerResponse((uid, req) => outing.execute(uid, String(req.params.outingId).toLowerCase())));

export default router;
