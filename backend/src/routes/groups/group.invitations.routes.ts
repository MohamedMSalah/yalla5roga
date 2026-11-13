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
 *       The caller must already belong to the group. Registered and unregistered phones
 *       are invited with pending status. Verified signup/login/sync links identity
 *       only; explicit acceptance creates membership. Duplicate pending invites
 *       and existing members retain the existing conflict response.
 *     operationId: inviteToGroup
 *     parameters:
 *       - $ref: "#/components/parameters/UuidId"
 *     requestBody:
 *       $ref: "#/components/requestBodies/InviteToGroup"
 *     responses:
 *       "201":
 *         description: A pending invitation was saved
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
 *     description: A group owner can revoke a pending phone association before acceptance, including identity-linked pending invitations.
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
