import { Router } from "express";
import { authMiddleware } from "../../middleware/auth.middleware.js";
import { UserInvitationsController } from "../../controllers/invitations/user-invitations.controller.js";
import { validate } from "../../middleware/validate.middleware.js";
import { invitationIdParamsSchema } from "../../validators/groups/group.validator.js";

/**
 * @openapi
 * /api/invitations:
 *   get:
 *     tags: [Invitations]
 *     summary: List invitation history and pending invitations for the current user
 *     description: >
 *       Returns group invitation history addressed to the authenticated user.
 *       Invitations are matched by `user_id` or, when `user_id` is still null, by the
 *       current Firebase-verified phone for pending unlinked rows. Each entry includes the
 *       group details and inviter name. Listing never accepts an invitation.
 *     operationId: listUserInvitations
 *     responses:
 *       "200":
 *         description: List of pending invitations
 *         content:
 *           application/json:
 *             schema:
 *               $ref: "#/components/schemas/UserInvitationListResponse"
 *       "401":
 *         $ref: "#/components/responses/Unauthorized"
 *       "500":
 *         $ref: "#/components/responses/InternalServerError"
 * /api/invitations/{invitationId}/accept:
 *   post:
 *     tags: [Invitations]
 *     summary: Accept a group invitation
 *     description: >
 *       Accepts a pending invitation and creates a group membership
 *       for the authenticated user. Idempotent — an already-decided
 *       invitation is returned with its persisted status and is never
 *       rewritten or auto-accepted by another request.
 *     operationId: acceptGroupInvitation
 *     parameters:
 *       - $ref: "#/components/parameters/InvitationId"
 *     responses:
 *       "200":
 *         description: Invitation accepted; group membership created
 *         content:
 *           application/json:
 *             schema:
 *               $ref: "#/components/schemas/AcceptInvitationResponse"
 *       "401":
 *         $ref: "#/components/responses/Unauthorized"
 *       "403":
 *         $ref: "#/components/responses/Forbidden"
 *       "404":
 *         $ref: "#/components/responses/NotFound"
 *       "500":
 *         $ref: "#/components/responses/InternalServerError"
 * /api/invitations/{invitationId}/decline:
 *   post:
 *     tags: [Invitations]
 *     summary: Decline a group invitation
 *     description: >
 *       Declines a pending invitation. The record is preserved with status
 *       `declined` but no group membership is created. Idempotent — a repeated
 *       or conflicting decision returns the persisted status instead of
 *       overwriting it.
 *     operationId: declineGroupInvitation
 *     parameters:
 *       - $ref: "#/components/parameters/InvitationId"
 *     responses:
 *       "200":
 *         description: Invitation declined
 *         content:
 *           application/json:
 *             schema:
 *               $ref: "#/components/schemas/DeclineInvitationResponse"
 *       "401":
 *         $ref: "#/components/responses/Unauthorized"
 *       "403":
 *         $ref: "#/components/responses/Forbidden"
 *       "404":
 *         $ref: "#/components/responses/NotFound"
 *       "500":
 *         $ref: "#/components/responses/InternalServerError"
 */
const api = Router();
api.use(authMiddleware);

const controller = new UserInvitationsController();

api.get("/", controller.list);
api.post(
  "/:invitationId/accept",
  validate({ params: invitationIdParamsSchema }),
  controller.accept,
);
api.post(
  "/:invitationId/decline",
  validate({ params: invitationIdParamsSchema }),
  controller.decline,
);

const router = Router();
router.use("/api/invitations", api);

export default router;
