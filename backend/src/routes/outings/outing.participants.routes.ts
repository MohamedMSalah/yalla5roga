import { Router } from "express";
import { OutingController } from "../../controllers/outings/outing.controller.js";
import { validate } from "../../middleware/validate.middleware.js";
import {
  addGuestBodySchema,
  attendanceBodySchema,
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
 *       "401":
 *         $ref: "#/components/responses/Unauthorized"
 *       "404":
 *         $ref: "#/components/responses/NotFound"
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
 *       "401":
 *         $ref: "#/components/responses/Unauthorized"
 *       "404":
 *         $ref: "#/components/responses/NotFound"
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

export default router;
