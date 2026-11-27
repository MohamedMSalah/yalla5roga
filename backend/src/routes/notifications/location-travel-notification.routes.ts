import { Router, type RequestHandler } from "express";
import { z } from "zod";
import { ownerResponse } from "../../controllers/users/saved-location.controller.js";
import { authMiddleware } from "../../middleware/auth.middleware.js";
import { validate } from "../../middleware/validate.middleware.js";
import { emitDataChange } from "../../realtime/data-changes.js";
import { RequestMemberLocationUseCase } from "../../usecases/meetups/request-member-location.usecase.js";
import {
  GetDepartureReminderPreferencesUseCase, InvalidateDepartureReminderUseCase,
  ScheduleDepartureReminderUseCase, UpdateDepartureReminderPreferencesUseCase,
} from "../../usecases/notifications/departure-reminder.usecases.js";

const preferencePath = "/api/users/me/departure-reminder-preferences";
const outingPath = "/api/outings/:outingId/my-departure-reminder";
const empty = z.strictObject({}).optional();

export function createLocationTravelNotificationRoutes(auth: RequestHandler = authMiddleware) {
  const router = Router();
  const request = new RequestMemberLocationUseCase();
  const get = new GetDepartureReminderPreferencesUseCase();
  const update = new UpdateDepartureReminderPreferencesUseCase();
  const schedule = new ScheduleDepartureReminderUseCase();
  const clear = new InvalidateDepartureReminderUseCase();
  const outingInputs = validate({ params: z.object({ outingId: z.uuid() }), body: empty, query: empty });

  router.post("/api/smart-meetups/:sessionId/location-requests", auth, validate({
    params: z.object({ sessionId: z.uuid() }),
    body: z.strictObject({ target_user_id: z.string().min(1).max(128) }),
    query: empty,
  }), ownerResponse(async (uid, req) => {
    const target = req.body.target_user_id as string;
    const result = await request.execute(uid, req.params.sessionId as string, target);
    if (result.status === "REQUESTED") emitDataChange({ kind: "inbox" }, [target]);
    return result;
  }));
  router.get(preferencePath, auth, validate({ body: empty, query: empty }), ownerResponse(uid => get.execute(uid)));
  router.patch(preferencePath, auth, validate({ query: empty, body: z.strictObject({
    enabled: z.boolean().optional(),
    preparation_buffer_minutes: z.literal([0, 5, 10, 15, 30]).optional(),
  }).refine(value => Object.keys(value).length > 0, "Provide at least one preference") }),
  ownerResponse((uid, req) => update.execute(uid, req.body)));
  router.get(outingPath, auth, outingInputs, ownerResponse((uid, req) => schedule.execute(uid, req.params.outingId as string, false)));
  router.put(outingPath, auth, outingInputs, ownerResponse((uid, req) => schedule.execute(uid, req.params.outingId as string, true)));
  router.delete(outingPath, auth, outingInputs, ownerResponse((uid, req) => clear.execute(uid, req.params.outingId as string)));
  return router;
}

export default createLocationTravelNotificationRoutes();
