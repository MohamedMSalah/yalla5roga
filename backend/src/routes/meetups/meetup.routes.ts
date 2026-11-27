import { Router, type RequestHandler } from "express";
import { z } from "zod";
import { authMiddleware } from "../../middleware/auth.middleware.js";
import { validate } from "../../middleware/validate.middleware.js";
import { MeetupSessionController } from "../../controllers/meetups/meetup-session.controller.js";
import { addManualParticipantBody, updateManualParticipantBody } from "../../validators/meetups/standalone-meetup.validator.js";
import { meetupPreferencesBody } from "../../validators/meetups/meetup-preferences.validator.js";

const params = z.object({ sessionId: z.uuid() });
const empty = z.strictObject({}).optional();
const noInputs = validate({ params, body: empty, query: empty });
const path = "/api/smart-meetups/:sessionId";
const participants = path + "/participants";
const participant = participants + "/:participantId";
const participantParams = params.extend({ participantId: z.uuid() });

export function createMeetupRoutes(auth: RequestHandler = authMiddleware) {
  const router = Router();
  const controller = new MeetupSessionController();
  router.post("/api/groups/:groupId/smart-meetup", auth, validate({
    params: z.object({ groupId: z.uuid() }), query: empty,
    body: z.strictObject({ outing_id: z.uuid().optional() }).optional(),
  }), controller.initialize);
  router.post("/api/smart-meetups/standalone", auth, validate({ body: empty, query: empty }), controller.createStandalone);
  router.get("/api/smart-meetups/filter-options", auth, validate({ body: empty, query: empty }), controller.filterOptions);
  router.get(participants, auth, noInputs, controller.listParticipants);
  router.post(participants, auth, validate({
    params, query: empty, body: addManualParticipantBody,
  }), controller.addParticipant);
  router.patch(participant, auth, validate({
    params: participantParams, query: empty, body: updateManualParticipantBody,
  }), controller.updateParticipant);
  router.delete(participant, auth, validate({
    params: participantParams, query: empty, body: empty,
  }), controller.removeParticipant);
  router.get(path + "/results", auth, noInputs, controller.results);
  router.post(path + "/calculate", auth, noInputs, controller.calculate);
  router.get(path + "/calculations/:calculationId", auth, validate({
    params: params.extend({ calculationId: z.uuid() }), query: empty, body: empty,
  }), controller.calculation);
  router.get(path, auth, noInputs, controller.get);
  router.get(path + "/readiness", auth, noInputs, controller.readiness);
  router.post(path + "/refresh", auth, noInputs, controller.get);
  router.get(path + "/preferences", auth, noInputs, controller.getPreferences);
  router.put(path + "/preferences", auth, validate({
    params, query: empty, body: meetupPreferencesBody,
  }), controller.updatePreferences);
  router.post(path + "/preferences/reset", auth, noInputs, controller.resetPreferences);
  router.patch(path + "/preferences", auth, validate({
    params, query: empty, body: z.strictObject({ optimization: z.enum(["BALANCED", "SHORTEST_TOTAL_TIME"]) }),
  }), controller.legacyPreferences);
  router.delete(path, auth, noInputs, controller.cancel);

  return router;
}

export default createMeetupRoutes();
