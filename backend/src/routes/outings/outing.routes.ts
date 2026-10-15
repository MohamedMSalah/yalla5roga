import { Router } from "express";
import { OutingController } from "../../controllers/outings/outing.controller.js";
import { authMiddleware } from "../../middleware/auth.middleware.js";
import { validate } from "../../middleware/validate.middleware.js";
import {
  addGuestBodySchema,
  attendanceBodySchema,
  castVoteBodySchema,
  createDraftBodySchema,
  createOutingBodySchema,
  createVoteOptionBodySchema,
  draftIdParamsSchema,
  guestParamsSchema,
  listOutingsQuerySchema,
  outingIdParamsSchema,
  updateDraftBodySchema,
  updateOutingBodySchema,
  voteParamsSchema,
} from "../../validators/outings/outing.validator.js";

/**
 * @openapi
 * /api/outings/drafts:
 *   get:
 *     tags: [Outings]
 *     summary: List the authenticated user's outing drafts
 *     operationId: listOutingDrafts
 *     responses:
 *       "200":
 *         description: Drafts
 *         content:
 *           application/json:
 *             schema:
 *               $ref: "#/components/schemas/OutingDraftListResponse"
 *       "401":
 *         $ref: "#/components/responses/Unauthorized"
 *       "500":
 *         $ref: "#/components/responses/InternalServerError"
 *   post:
 *     tags: [Outings]
 *     summary: Create an outing draft
 *     description: "user_id is taken from the authenticated Firebase UID."
 *     operationId: createOutingDraft
 *     requestBody:
 *       $ref: "#/components/requestBodies/OutingDraft"
 *     responses:
 *       "201":
 *         description: Created draft
 *         content:
 *           application/json:
 *             schema:
 *               $ref: "#/components/schemas/OutingDraftResponse"
 *       "400":
 *         $ref: "#/components/responses/BadRequest"
 *       "401":
 *         $ref: "#/components/responses/Unauthorized"
 *       "500":
 *         $ref: "#/components/responses/InternalServerError"
 * /api/outings/drafts/{id}:
 *   patch:
 *     tags: [Outings]
 *     summary: Update an outing draft
 *     description: Allowed only for the draft owner.
 *     operationId: updateOutingDraft
 *     parameters:
 *       - $ref: "#/components/parameters/UuidId"
 *     requestBody:
 *       $ref: "#/components/requestBodies/OutingDraft"
 *     responses:
 *       "200":
 *         description: Updated draft
 *         content:
 *           application/json:
 *             schema:
 *               $ref: "#/components/schemas/OutingDraftResponse"
 *       "400":
 *         $ref: "#/components/responses/BadRequest"
 *       "401":
 *         $ref: "#/components/responses/Unauthorized"
 *       "403":
 *         $ref: "#/components/responses/Forbidden"
 *       "404":
 *         $ref: "#/components/responses/NotFound"
 *       "500":
 *         $ref: "#/components/responses/InternalServerError"
 *   delete:
 *     tags: [Outings]
 *     summary: Delete an outing draft
 *     description: Allowed only for the draft owner.
 *     operationId: deleteOutingDraft
 *     parameters:
 *       - $ref: "#/components/parameters/UuidId"
 *     responses:
 *       "200":
 *         description: Deleted draft
 *         content:
 *           application/json:
 *             schema:
 *               $ref: "#/components/schemas/OutingDraftResponse"
 *       "400":
 *         $ref: "#/components/responses/BadRequest"
 *       "401":
 *         $ref: "#/components/responses/Unauthorized"
 *       "403":
 *         $ref: "#/components/responses/Forbidden"
 *       "404":
 *         $ref: "#/components/responses/NotFound"
 *       "500":
 *         $ref: "#/components/responses/InternalServerError"
 * /api/outings:
 *   get:
 *     tags: [Outings]
 *     summary: List outings
 *     description: "userId defaults to the authenticated user when omitted."
 *     operationId: listOutings
 *     parameters:
 *       - in: query
 *         name: groupId
 *         required: false
 *         schema:
 *           type: string
 *           format: uuid
 *       - in: query
 *         name: userId
 *         required: false
 *         schema:
 *           type: string
 *           minLength: 1
 *     responses:
 *       "200":
 *         description: Outings
 *         content:
 *           application/json:
 *             schema:
 *               $ref: "#/components/schemas/OutingListResponse"
 *       "400":
 *         $ref: "#/components/responses/BadRequest"
 *       "401":
 *         $ref: "#/components/responses/Unauthorized"
 *       "500":
 *         $ref: "#/components/responses/InternalServerError"
 *   post:
 *     tags: [Outings]
 *     summary: Create an outing
 *     description: "created_by is taken from the authenticated Firebase UID."
 *     operationId: createOuting
 *     requestBody:
 *       $ref: "#/components/requestBodies/CreateOuting"
 *     responses:
 *       "201":
 *         description: Created outing
 *         content:
 *           application/json:
 *             schema:
 *               $ref: "#/components/schemas/OutingResponse"
 *       "400":
 *         $ref: "#/components/responses/BadRequest"
 *       "401":
 *         $ref: "#/components/responses/Unauthorized"
 *       "500":
 *         $ref: "#/components/responses/InternalServerError"
 * /api/outings/{id}/attendance:
 *   get:
 *     tags: [Outings]
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
 *     tags: [Outings]
 *     summary: Set the authenticated user's attendance
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
 *     tags: [Outings]
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
 *     tags: [Outings]
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
 *     tags: [Outings]
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
 * /api/outings/{id}/vote-options:
 *   get:
 *     tags: [Outings]
 *     summary: List vote options
 *     operationId: listVoteOptions
 *     parameters:
 *       - $ref: "#/components/parameters/UuidId"
 *     responses:
 *       "200":
 *         description: Vote options
 *         content:
 *           application/json:
 *             schema:
 *               $ref: "#/components/schemas/VoteOptionListResponse"
 *       "400":
 *         $ref: "#/components/responses/BadRequest"
 *       "401":
 *         $ref: "#/components/responses/Unauthorized"
 *       "404":
 *         $ref: "#/components/responses/NotFound"
 *       "500":
 *         $ref: "#/components/responses/InternalServerError"
 *   post:
 *     tags: [Outings]
 *     summary: Add a vote option
 *     operationId: createVoteOption
 *     parameters:
 *       - $ref: "#/components/parameters/UuidId"
 *     requestBody:
 *       $ref: "#/components/requestBodies/CreateVoteOption"
 *     responses:
 *       "201":
 *         description: Created vote option
 *         content:
 *           application/json:
 *             schema:
 *               $ref: "#/components/schemas/VoteOptionResponse"
 *       "400":
 *         $ref: "#/components/responses/BadRequest"
 *       "401":
 *         $ref: "#/components/responses/Unauthorized"
 *       "404":
 *         $ref: "#/components/responses/NotFound"
 *       "500":
 *         $ref: "#/components/responses/InternalServerError"
 * /api/outings/{id}/vote-options/{optionId}:
 *   delete:
 *     tags: [Outings]
 *     summary: Delete a vote option
 *     operationId: deleteVoteOption
 *     parameters:
 *       - $ref: "#/components/parameters/UuidId"
 *       - $ref: "#/components/parameters/OptionId"
 *     responses:
 *       "200":
 *         description: Deleted vote option
 *         content:
 *           application/json:
 *             schema:
 *               $ref: "#/components/schemas/VoteOptionResponse"
 *       "400":
 *         $ref: "#/components/responses/BadRequest"
 *       "401":
 *         $ref: "#/components/responses/Unauthorized"
 *       "500":
 *         $ref: "#/components/responses/InternalServerError"
 * /api/outings/{id}/votes:
 *   get:
 *     tags: [Outings]
 *     summary: List votes
 *     operationId: listVotes
 *     parameters:
 *       - $ref: "#/components/parameters/UuidId"
 *     responses:
 *       "200":
 *         description: Votes
 *         content:
 *           application/json:
 *             schema:
 *               $ref: "#/components/schemas/VoteListResponse"
 *       "400":
 *         $ref: "#/components/responses/BadRequest"
 *       "401":
 *         $ref: "#/components/responses/Unauthorized"
 *       "404":
 *         $ref: "#/components/responses/NotFound"
 *       "500":
 *         $ref: "#/components/responses/InternalServerError"
 *   post:
 *     tags: [Outings]
 *     summary: Cast a vote
 *     description: The voter is the authenticated Firebase UID.
 *     operationId: castVote
 *     parameters:
 *       - $ref: "#/components/parameters/UuidId"
 *     requestBody:
 *       $ref: "#/components/requestBodies/CastVote"
 *     responses:
 *       "201":
 *         description: Recorded vote
 *         content:
 *           application/json:
 *             schema:
 *               $ref: "#/components/schemas/VoteResponse"
 *       "400":
 *         $ref: "#/components/responses/BadRequest"
 *       "401":
 *         $ref: "#/components/responses/Unauthorized"
 *       "404":
 *         $ref: "#/components/responses/NotFound"
 *       "500":
 *         $ref: "#/components/responses/InternalServerError"
 * /api/outings/{id}/votes/{optionId}:
 *   delete:
 *     tags: [Outings]
 *     summary: Remove the authenticated user's vote for an option
 *     operationId: removeVote
 *     parameters:
 *       - $ref: "#/components/parameters/UuidId"
 *       - $ref: "#/components/parameters/OptionId"
 *     responses:
 *       "200":
 *         description: Removed vote
 *         content:
 *           application/json:
 *             schema:
 *               $ref: "#/components/schemas/VoteResponse"
 *       "400":
 *         $ref: "#/components/responses/BadRequest"
 *       "401":
 *         $ref: "#/components/responses/Unauthorized"
 *       "500":
 *         $ref: "#/components/responses/InternalServerError"
 * /api/outings/{id}:
 *   get:
 *     tags: [Outings]
 *     summary: Get an outing
 *     operationId: getOuting
 *     parameters:
 *       - $ref: "#/components/parameters/UuidId"
 *     responses:
 *       "200":
 *         description: Outing
 *         content:
 *           application/json:
 *             schema:
 *               $ref: "#/components/schemas/OutingResponse"
 *       "400":
 *         $ref: "#/components/responses/BadRequest"
 *       "401":
 *         $ref: "#/components/responses/Unauthorized"
 *       "404":
 *         $ref: "#/components/responses/NotFound"
 *       "500":
 *         $ref: "#/components/responses/InternalServerError"
 *   patch:
 *     tags: [Outings]
 *     summary: Update an outing
 *     operationId: updateOuting
 *     parameters:
 *       - $ref: "#/components/parameters/UuidId"
 *     requestBody:
 *       $ref: "#/components/requestBodies/UpdateOuting"
 *     responses:
 *       "200":
 *         description: Updated outing
 *         content:
 *           application/json:
 *             schema:
 *               $ref: "#/components/schemas/OutingResponse"
 *       "400":
 *         $ref: "#/components/responses/BadRequest"
 *       "401":
 *         $ref: "#/components/responses/Unauthorized"
 *       "404":
 *         $ref: "#/components/responses/NotFound"
 *       "500":
 *         $ref: "#/components/responses/InternalServerError"
 *   delete:
 *     tags: [Outings]
 *     summary: Delete an outing
 *     operationId: deleteOuting
 *     parameters:
 *       - $ref: "#/components/parameters/UuidId"
 *     responses:
 *       "200":
 *         description: Deleted outing
 *         content:
 *           application/json:
 *             schema:
 *               $ref: "#/components/schemas/OutingResponse"
 *       "400":
 *         $ref: "#/components/responses/BadRequest"
 *       "401":
 *         $ref: "#/components/responses/Unauthorized"
 *       "404":
 *         $ref: "#/components/responses/NotFound"
 *       "500":
 *         $ref: "#/components/responses/InternalServerError"
 */
const api = Router();
const controller = new OutingController();

api.use(authMiddleware);

api.get("/drafts", controller.getDrafts);
api.post(
  "/drafts",
  validate({ body: createDraftBodySchema }),
  controller.addDraft,
);
api.patch(
  "/drafts/:id",
  validate({ params: draftIdParamsSchema, body: updateDraftBodySchema }),
  controller.editDraft,
);
api.delete(
  "/drafts/:id",
  validate({ params: draftIdParamsSchema }),
  controller.removeDraft,
);

api.get(
  "/",
  validate({ query: listOutingsQuerySchema }),
  controller.list,
);
/**
 * @openapi
 * /api/outings/cuser:
 *   get:
 *     tags: [Outings]
 *     summary: List outings for the authenticated user
 *     description: Uses only the Firebase UID on the Bearer token. Includes outings the user created, was invited to, or can see through a group membership.
 *     operationId: listCurrentUserOutings
 *     responses:
 *       "200":
 *         description: Outings for the authenticated user
 *         content:
 *           application/json:
 *             schema:
 *               $ref: "#/components/schemas/OutingListResponse"
 *       "401":
 *         $ref: "#/components/responses/Unauthorized"
 *       "500":
 *         $ref: "#/components/responses/InternalServerError"
 */
api.get("/cuser", controller.listForCuser);
api.post(
  "/",
  validate({ body: createOutingBodySchema }),
  controller.create,
);

// Attendance
api.get(
  "/:id/attendance",
  validate({ params: outingIdParamsSchema }),
  controller.getAttendance,
);
api.put(
  "/:id/attendance",
  validate({ params: outingIdParamsSchema, body: attendanceBodySchema }),
  controller.setAttendance,
);

// Guests
api.get(
  "/:id/guests",
  validate({ params: outingIdParamsSchema }),
  controller.getGuests,
);
api.post(
  "/:id/guests",
  validate({ params: outingIdParamsSchema, body: addGuestBodySchema }),
  controller.inviteGuest,
);
api.delete(
  "/:id/guests/:userId",
  validate({ params: guestParamsSchema }),
  controller.uninviteGuest,
);

// Voting
api.get(
  "/:id/vote-options",
  validate({ params: outingIdParamsSchema }),
  controller.getVoteOptions,
);
api.post(
  "/:id/vote-options",
  validate({
    params: outingIdParamsSchema,
    body: createVoteOptionBodySchema,
  }),
  controller.addVoteOption,
);
api.delete(
  "/:id/vote-options/:optionId",
  validate({ params: voteParamsSchema }),
  controller.removeVoteOption,
);
api.get(
  "/:id/votes",
  validate({ params: outingIdParamsSchema }),
  controller.getVotes,
);
api.post(
  "/:id/votes",
  validate({ params: outingIdParamsSchema, body: castVoteBodySchema }),
  controller.vote,
);
api.delete(
  "/:id/votes/:optionId",
  validate({ params: voteParamsSchema }),
  controller.unvote,
);

api.get(
  "/:id",
  validate({ params: outingIdParamsSchema }),
  controller.getById,
);
api.patch(
  "/:id",
  validate({ params: outingIdParamsSchema, body: updateOutingBodySchema }),
  controller.update,
);
api.delete(
  "/:id",
  validate({ params: outingIdParamsSchema }),
  controller.remove,
);

const router = Router();
router.use("/api/outings", api);

export default router;
