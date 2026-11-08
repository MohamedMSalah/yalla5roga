import { Router } from "express";
import { GroupController } from "../../controllers/groups/group.controller.js";
import { validate } from "../../middleware/validate.middleware.js";
import {
  groupIdParamsSchema,
  invitationIdParamsSchema,
  inviteToGroupBodySchema,
} from "../../validators/groups/group.validator.js";

/**
 * @openapi
 * /api/groups/{id}/invitations:
 *   post:
 *     tags: [Group Invitations]
 *     summary: Invite a phone number to a group
 *     description: >
 *       The caller must already belong to the group. A verified Firebase account
 *       with this phone is added as a member immediately. Otherwise a pending
 *       invitation is stored and a WhatsApp click-to-chat URL is returned.
 *       Opening that URL does not send the message; the inviter sends it.
 *       The message does not include store links until the app is published.
 *     operationId: inviteToGroup
 *     parameters:
 *       - $ref: "#/components/parameters/UuidId"
 *     requestBody:
 *       $ref: "#/components/requestBodies/InviteToGroup"
 *     responses:
 *       "201":
 *         description: Member added, or a pending invitation was saved
 *         content:
 *           application/json:
 *             schema:
 *               $ref: "#/components/schemas/GroupInvitationResponse"
 *       "400":
 *         $ref: "#/components/responses/BadRequest"
 *       "401":
 *         $ref: "#/components/responses/Unauthorized"
 *       "403":
 *         $ref: "#/components/responses/Forbidden"
 *       "404":
 *         $ref: "#/components/responses/NotFound"
 *       "409":
 *         description: The phone already has a pending invitation or is already a member
 *         content:
 *           application/json:
 *             schema:
 *               $ref: "#/components/schemas/GroupInvitationConflict"
 *       "500":
 *         $ref: "#/components/responses/InternalServerError"
 * /api/groups/invitations/{invitationId}/decline:
 *   post:
 *     tags: [Group Invitations]
 *     summary: Decline a pending group invitation
 *     description: >
 *       The invitation must be pending and addressed to the phone number verified on the
 *       caller's Firebase ID token. The UID and phone come from the token only. A repeated
 *       call finds no pending row and returns 404.
 *     operationId: declineGroupInvitation
 *     parameters:
 *       - $ref: "#/components/parameters/InvitationId"
 *     responses:
 *       "200":
 *         description: The invitation, now with status declined
 *         content:
 *           application/json:
 *             schema:
 *               $ref: "#/components/schemas/GroupInvitationRecordResponse"
 *       "400":
 *         $ref: "#/components/responses/BadRequest"
 *       "401":
 *         $ref: "#/components/responses/Unauthorized"
 *       "403":
 *         description: The token carries no verified phone number
 *         content:
 *           application/json:
 *             schema:
 *               $ref: "#/components/schemas/ErrorResponse"
 *       "404":
 *         description: No pending invitation for this id and verified phone
 *         content:
 *           application/json:
 *             schema:
 *               $ref: "#/components/schemas/ErrorResponse"
 *       "500":
 *         $ref: "#/components/responses/InternalServerError"
 */
const router = Router();
const controller = new GroupController();

// Static `/invitations/:invitationId/decline` before `/:id`.
router.post(
  "/invitations/:invitationId/decline",
  validate({ params: invitationIdParamsSchema }),
  controller.decline,
);
router.post(
  "/:id/invitations",
  validate({ params: groupIdParamsSchema, body: inviteToGroupBodySchema }),
  controller.invite,
);

export default router;
