import { Router } from "express";
import { GroupController } from "../../controllers/groups/group.controller.js";
import { validate } from "../../middleware/validate.middleware.js";
import {
  groupIdParamsSchema,
  pendingMembershipParamsSchema,
  inviteToGroupBodySchema,
} from "../../validators/groups/group.validator.js";

/**
 * @openapi
 * /api/groups/{id}/invitations:
 *   post:
 *     tags: [Group Invitations]
 *     summary: Add a phone number to a group
 *     description: >
 *       The caller must already belong to the group. A verified Firebase account
 *       with this phone and a synced profile is added immediately. Otherwise a
 *       phone association is saved until verified signup or sync. A consented
 *       WhatsApp Business template is queued when the provider is configured.
 *       Registration links the group without an acceptance step.
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
 * /api/groups/{id}/pending-memberships/{invitationId}:
 *   delete:
 *     tags: [Group Invitations]
 *     summary: Revoke a pending phone membership
 *     description: A group owner can revoke a pending phone association before it links to an account.
 *     operationId: revokePendingGroupMembership
 *     parameters:
 *       - $ref: "#/components/parameters/UuidId"
 *       - $ref: "#/components/parameters/InvitationId"
 *     responses:
 *       "200":
 *         description: The pending association was revoked
 *         content:
 *           application/json:
 *             schema:
 *               $ref: "#/components/schemas/GroupInvitationRecordResponse"
 *       "400":
 *         $ref: "#/components/responses/BadRequest"
 *       "401":
 *         $ref: "#/components/responses/Unauthorized"
 *       "403":
 *         $ref: "#/components/responses/Forbidden"
 *       "404":
 *         $ref: "#/components/responses/NotFound"
 */
const router = Router();
const controller = new GroupController();

router.delete(
  "/:id/pending-memberships/:invitationId",
  validate({ params: pendingMembershipParamsSchema }),
  controller.revokePendingMembership,
);
router.post(
  "/:id/invitations",
  validate({ params: groupIdParamsSchema, body: inviteToGroupBodySchema }),
  controller.invite,
);

export default router;
