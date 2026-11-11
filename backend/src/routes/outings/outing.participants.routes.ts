import { Router } from "express";
import { OutingController } from "../../controllers/outings/outing.controller.js";
import { validate } from "../../middleware/validate.middleware.js";
import {
  addGuestBodySchema,
  attendanceBodySchema,
  arrivalBodySchema,
  guestParamsSchema,
  outingIdParamsSchema,
} from "../../validators/outings/outing.validator.js";

/**
 * @openapi
 * /api/outings/{id}/attendance:
 *   get:
 *     tags: [Outing Participants]
 *     summary: List attendance for an outing
 *     operationId: listOutingAttendance
 *     parameters:
 *       - $ref: "#/components/parameters/UuidId"
 *     responses:
 *       "200":
 *         description: Attendance rows
 *         content:
 *           application/json:
 *             schema:
 *               $ref: "#/components/schemas/AttendanceListResponse"
 *       "400":
 *         $ref: "#/components/responses/BadRequest"
 *       "401":
 *         $ref: "#/components/responses/Unauthorized"
 *       "404":
 *         $ref: "#/components/responses/NotFound"
 *       "500":
 *         $ref: "#/components/responses/InternalServerError"
 *       "403":
 *         $ref: "#/components/responses/Forbidden"
 *   put:
 *     tags: [Outing Participants]
 *     summary: Set my attendance for an outing
 *     description: Upserts attendance for the authenticated Firebase UID.
 *     operationId: setOutingAttendance
 *     parameters:
 *       - $ref: "#/components/parameters/UuidId"
 *     requestBody:
 *       $ref: "#/components/requestBodies/Attendance"
 *     responses:
 *       "200":
 *         description: Saved attendance
 *         content:
 *           application/json:
 *             schema:
 *               $ref: "#/components/schemas/AttendanceResponse"
 *       "400":
 *         $ref: "#/components/responses/BadRequest"
 *       "401":
 *         $ref: "#/components/responses/Unauthorized"
 *       "404":
 *         $ref: "#/components/responses/NotFound"
 *       "500":
 *         $ref: "#/components/responses/InternalServerError"
 *       "403":
 *         $ref: "#/components/responses/Forbidden"
 *       "409":
 *         description: The request conflicts with the current resource state
 *         content:
 *           application/json:
 *             schema:
 *               $ref: "#/components/schemas/ErrorResponse"
 * /api/outings/{id}/guests:
 *   get:
 *     tags: [Outing Participants]
 *     summary: List outing guests
 *     operationId: listOutingGuests
 *     parameters:
 *       - $ref: "#/components/parameters/UuidId"
 *     responses:
 *       "200":
 *         description: Guests
 *         content:
 *           application/json:
 *             schema:
 *               $ref: "#/components/schemas/GuestListResponse"
 *       "400":
 *         $ref: "#/components/responses/BadRequest"
 *       "401":
 *         $ref: "#/components/responses/Unauthorized"
 *       "404":
 *         $ref: "#/components/responses/NotFound"
 *       "500":
 *         $ref: "#/components/responses/InternalServerError"
 *       "403":
 *         $ref: "#/components/responses/Forbidden"
 *   post:
 *     tags: [Outing Participants]
 *     summary: Invite a guest
 *     operationId: inviteOutingGuest
 *     parameters:
 *       - $ref: "#/components/parameters/UuidId"
 *     requestBody:
 *       $ref: "#/components/requestBodies/AddGuest"
 *     responses:
 *       "201":
 *         description: Created guest invitation
 *         content:
 *           application/json:
 *             schema:
 *               $ref: "#/components/schemas/GuestResponse"
 *       "400":
 *         $ref: "#/components/responses/BadRequest"
 *       "401":
 *         $ref: "#/components/responses/Unauthorized"
 *       "404":
 *         $ref: "#/components/responses/NotFound"
 *       "500":
 *         $ref: "#/components/responses/InternalServerError"
 *       "403":
 *         $ref: "#/components/responses/Forbidden"
 *       "409":
 *         description: The request conflicts with the current resource state
 *         content:
 *           application/json:
 *             schema:
 *               $ref: "#/components/schemas/ErrorResponse"
 * /api/outings/{id}/guests/{userId}:
 *   delete:
 *     tags: [Outing Participants]
 *     summary: Remove a guest
 *     operationId: removeOutingGuest
 *     parameters:
 *       - $ref: "#/components/parameters/UuidId"
 *       - $ref: "#/components/parameters/MemberUserId"
 *     responses:
 *       "200":
 *         description: Removed guest
 *         content:
 *           application/json:
 *             schema:
 *               $ref: "#/components/schemas/GuestResponse"
 *       "400":
 *         $ref: "#/components/responses/BadRequest"
 *       "401":
 *         $ref: "#/components/responses/Unauthorized"
 *       "404":
 *         $ref: "#/components/responses/NotFound"
 *       "500":
 *         $ref: "#/components/responses/InternalServerError"
 *       "403":
 *         $ref: "#/components/responses/Forbidden"
 * /api/outings/{id}/invitations/accept:
 *   post:
 *     tags: [Outing Participants]
 *     summary: Accept an outing invitation
 *     operationId: acceptOutingInvitation
 *     parameters:
 *       - $ref: "#/components/parameters/UuidId"
 *     responses:
 *       "200":
 *         description: Accepted guest membership
 *         content:
 *           application/json:
 *             schema:
 *               $ref: "#/components/schemas/GuestResponse"
 *       "401":
 *         $ref: "#/components/responses/Unauthorized"
 *       "404":
 *         $ref: "#/components/responses/NotFound"
 *       "409":
 *         description: The request conflicts with the current resource state
 *         content:
 *           application/json:
 *             schema:
 *               $ref: "#/components/schemas/ErrorResponse"
 * /api/outings/{id}/invitations/decline:
 *   post:
 *     tags: [Outing Participants]
 *     summary: Decline an outing invitation
 *     operationId: declineOutingInvitation
 *     parameters:
 *       - $ref: "#/components/parameters/UuidId"
 *     responses:
 *       "200":
 *         description: Declined invitation
 *         content:
 *           application/json:
 *             schema:
 *               $ref: "#/components/schemas/GuestResponse"
 *       "401":
 *         $ref: "#/components/responses/Unauthorized"
 *       "404":
 *         $ref: "#/components/responses/NotFound"
 *       "409":
 *         description: The request conflicts with the current resource state
 *         content:
 *           application/json:
 *             schema:
 *               $ref: "#/components/schemas/ErrorResponse"
 */
const router = Router();
const controller = new OutingController();

router.get(
  "/:id/attendance",
  validate({ params: outingIdParamsSchema }),
  controller.getAttendance,
);
router.put(
  "/:id/attendance",
  validate({ params: outingIdParamsSchema, body: attendanceBodySchema }),
  controller.setAttendance,
);

router.get(
  "/:id/guests",
  validate({ params: outingIdParamsSchema }),
  controller.getGuests,
);
router.post(
  "/:id/guests",
  validate({ params: outingIdParamsSchema, body: addGuestBodySchema }),
  controller.inviteGuest,
);
router.post(
  "/:id/invitations/accept",
  validate({ params: outingIdParamsSchema }),
  controller.acceptInvite,
);
router.post(
  "/:id/invitations/decline",
  validate({ params: outingIdParamsSchema }),
  controller.declineInvite,
);
router.delete(
  "/:id/guests/:userId",
  validate({ params: guestParamsSchema }),
  controller.uninviteGuest,
);

/**
 * @openapi
 * /api/outings/{id}/arrivals:
 *   get:
 *     tags: [Outing Participants]
 *     summary: List participant arrivals for an outing
 *     operationId: listOutingArrivals
 *     parameters:
 *       - $ref: "#/components/parameters/UuidId"
 *     responses:
 *       "200":
 *         description: Arrival list and current check-in window state
 *         content:
 *           application/json:
 *             schema:
 *               $ref: "#/components/schemas/OutingArrivalsResponse"
 *       "400":
 *         $ref: "#/components/responses/BadRequest"
 *       "401":
 *         $ref: "#/components/responses/Unauthorized"
 *       "403":
 *         $ref: "#/components/responses/Forbidden"
 *       "404":
 *         $ref: "#/components/responses/NotFound"
 * /api/outings/{id}/arrivals/self:
 *   put:
 *     tags: [Outing Participants]
 *     summary: Record the signed-in participantâ€™s first arrival
 *     operationId: recordOutingArrival
 *     parameters:
 *       - $ref: "#/components/parameters/UuidId"
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required: [latitude, longitude, accuracy, captured_at]
 *             properties:
 *               captured_at: { type: string, format: date-time }
 *               method: { type: string, enum: [gps, automatic_gps] }
 *               is_mocked: { type: boolean }
 *               latitude: { type: number, minimum: -90, maximum: 90 }
 *               longitude: { type: number, minimum: -180, maximum: 180 }
 *               accuracy: { type: number, minimum: 0, exclusiveMinimum: true, maximum: 10000, description: Device accuracy in meters }
 *     responses:
 *       "200":
 *         description: Whether the participant is recorded as arrived
 *         content:
 *           application/json:
 *             schema:
 *               $ref: "#/components/schemas/OutingArrivalResponse"
 *       "400":
 *         $ref: "#/components/responses/BadRequest"
 *       "401":
 *         $ref: "#/components/responses/Unauthorized"
 *       "403":
 *         $ref: "#/components/responses/Forbidden"
 *       "404":
 *         $ref: "#/components/responses/NotFound"
 */
router.get(
  "/:id/arrivals",
  validate({ params: outingIdParamsSchema }),
  controller.listArrivals,
);
router.put(
  "/:id/arrivals/self",
  validate({ params: outingIdParamsSchema, body: arrivalBodySchema }),
  controller.recordArrival,
);

export default router;
