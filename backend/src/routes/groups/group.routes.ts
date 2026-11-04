import { Router } from "express";
import { GroupController } from "../../controllers/groups/group.controller.js";
import { authMiddleware } from "../../middleware/auth.middleware.js";
import { validate } from "../../middleware/validate.middleware.js";
import {
  addGroupMemberBodySchema,
  createGroupBodySchema,
  groupIdParamsSchema,
  groupMemberParamsSchema,
  invitationIdParamsSchema,
  inviteToGroupBodySchema,
  listGroupsQuerySchema,
  updateGroupBodySchema,
} from "../../validators/groups/group.validator.js";

/**
 * @openapi
 * /api/groups/cuser:
 *   get:
 *     tags: [Groups]
 *     summary: List my groups
 *     description: >
 *       Uses only the Firebase UID on the Bearer token. Returns groups where
 *       the caller is a member.
 *     operationId: listCurrentUserGroups
 *     responses:
 *       "200":
 *         description: Groups for the authenticated user
 *         content:
 *           application/json:
 *             schema:
 *               $ref: "#/components/schemas/GroupListResponse"
 *       "401":
 *         $ref: "#/components/responses/Unauthorized"
 *       "500":
 *         $ref: "#/components/responses/InternalServerError"
 * /api/groups:
 *   get:
 *     tags: [Groups]
 *     summary: List groups
 *     description: >
 *       Filters by the `userId` query when present, otherwise by the
 *       authenticated user.
 *     operationId: listGroups
 *     parameters:
 *       - in: query
 *         name: userId
 *         required: false
 *         schema:
 *           type: string
 *           minLength: 1
 *         description: Firebase UID. Defaults to the authenticated user.
 *     responses:
 *       "200":
 *         description: Groups for the selected user
 *         content:
 *           application/json:
 *             schema:
 *               $ref: "#/components/schemas/GroupListResponse"
 *       "400":
 *         $ref: "#/components/responses/BadRequest"
 *       "401":
 *         $ref: "#/components/responses/Unauthorized"
 *       "500":
 *         $ref: "#/components/responses/InternalServerError"
 *   post:
 *     tags: [Groups]
 *     summary: Create a group
 *     description: >
 *       created_by is taken from the authenticated Firebase UID.
 *       image_url is optional; omit it or send an empty string for the default cover.
 *     operationId: createGroup
 *     requestBody:
 *       $ref: "#/components/requestBodies/CreateGroup"
 *     responses:
 *       "201":
 *         description: Created group
 *         content:
 *           application/json:
 *             schema:
 *               $ref: "#/components/schemas/GroupResponse"
 *       "400":
 *         $ref: "#/components/responses/BadRequest"
 *       "401":
 *         $ref: "#/components/responses/Unauthorized"
 *       "500":
 *         $ref: "#/components/responses/InternalServerError"
 * /api/groups/{id}:
 *   get:
 *     tags: [Groups]
 *     summary: Get a group
 *     description: Returns a single group by UUID.
 *     operationId: getGroup
 *     parameters:
 *       - $ref: "#/components/parameters/UuidId"
 *     responses:
 *       "200":
 *         description: Group
 *         content:
 *           application/json:
 *             schema:
 *               $ref: "#/components/schemas/GroupResponse"
 *       "400":
 *         $ref: "#/components/responses/BadRequest"
 *       "401":
 *         $ref: "#/components/responses/Unauthorized"
 *       "404":
 *         $ref: "#/components/responses/NotFound"
 *       "500":
 *         $ref: "#/components/responses/InternalServerError"
 *   patch:
 *     tags: [Groups]
 *     summary: Update a group
 *     description: Updates group fields for the given UUID.
 *     operationId: updateGroup
 *     parameters:
 *       - $ref: "#/components/parameters/UuidId"
 *     requestBody:
 *       $ref: "#/components/requestBodies/UpdateGroup"
 *     responses:
 *       "200":
 *         description: Updated group
 *         content:
 *           application/json:
 *             schema:
 *               $ref: "#/components/schemas/GroupResponse"
 *       "400":
 *         $ref: "#/components/responses/BadRequest"
 *       "401":
 *         $ref: "#/components/responses/Unauthorized"
 *       "404":
 *         $ref: "#/components/responses/NotFound"
 *       "500":
 *         $ref: "#/components/responses/InternalServerError"
 *   delete:
 *     tags: [Groups]
 *     summary: Delete a group
 *     description: Deletes the group with the given UUID.
 *     operationId: deleteGroup
 *     parameters:
 *       - $ref: "#/components/parameters/UuidId"
 *     responses:
 *       "200":
 *         description: Deleted group
 *         content:
 *           application/json:
 *             schema:
 *               $ref: "#/components/schemas/GroupResponse"
 *       "400":
 *         $ref: "#/components/responses/BadRequest"
 *       "401":
 *         $ref: "#/components/responses/Unauthorized"
 *       "404":
 *         $ref: "#/components/responses/NotFound"
 *       "500":
 *         $ref: "#/components/responses/InternalServerError"
 * /api/groups/{id}/members:
 *   get:
 *     tags: [Groups]
 *     summary: List group members
 *     description: Returns memberships for the group.
 *     operationId: listGroupMembers
 *     parameters:
 *       - $ref: "#/components/parameters/UuidId"
 *     responses:
 *       "200":
 *         description: Members of the group
 *         content:
 *           application/json:
 *             schema:
 *               $ref: "#/components/schemas/GroupMemberListResponse"
 *       "400":
 *         $ref: "#/components/responses/BadRequest"
 *       "401":
 *         $ref: "#/components/responses/Unauthorized"
 *       "404":
 *         $ref: "#/components/responses/NotFound"
 *       "500":
 *         $ref: "#/components/responses/InternalServerError"
 *   post:
 *     tags: [Groups]
 *     summary: Add a group member by phone number
 *     description: Adds an existing user to the group using their phone number.
 *     operationId: addGroupMember
 *     parameters:
 *       - $ref: "#/components/parameters/UuidId"
 *     requestBody:
 *       $ref: "#/components/requestBodies/AddGroupMember"
 *     responses:
 *       "201":
 *         description: Created membership
 *         content:
 *           application/json:
 *             schema:
 *               $ref: "#/components/schemas/GroupMemberResponse"
 *       "400":
 *         $ref: "#/components/responses/BadRequest"
 *       "401":
 *         $ref: "#/components/responses/Unauthorized"
 *       "404":
 *         $ref: "#/components/responses/NotFound"
 *       "500":
 *         $ref: "#/components/responses/InternalServerError"
 * /api/groups/{id}/members/{userId}:
 *   delete:
 *     tags: [Groups]
 *     summary: Remove a group member
 *     description: Removes the given user from the group.
 *     operationId: removeGroupMember
 *     parameters:
 *       - $ref: "#/components/parameters/UuidId"
 *       - $ref: "#/components/parameters/MemberUserId"
 *     responses:
 *       "200":
 *         description: Removed membership
 *         content:
 *           application/json:
 *             schema:
 *               $ref: "#/components/schemas/GroupMemberResponse"
 *       "400":
 *         $ref: "#/components/responses/BadRequest"
 *       "401":
 *         $ref: "#/components/responses/Unauthorized"
 *       "404":
 *         $ref: "#/components/responses/NotFound"
 *       "500":
 *         $ref: "#/components/responses/InternalServerError"
 * /api/groups/{id}/invitations:
 *   post:
 *     tags: [Groups]
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
 *     tags: [Groups]
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
const api = Router();
const controller = new GroupController();

api.use(authMiddleware);

// Static paths before /:id so "cuser" and "invitations" are never treated as group ids.
api.get("/cuser", controller.listForCuser);
api.get(
  "/",
  validate({ query: listGroupsQuerySchema }),
  controller.list,
);
api.post(
  "/",
  validate({ body: createGroupBodySchema }),
  controller.create,
);
api.post(
  "/invitations/:invitationId/decline",
  validate({ params: invitationIdParamsSchema }),
  controller.decline,
);
api.get(
  "/:id/members",
  validate({ params: groupIdParamsSchema }),
  controller.members,
);
api.post(
  "/:id/members",
  validate({ params: groupIdParamsSchema, body: addGroupMemberBodySchema }),
  controller.addGroupMember,
);
api.delete(
  "/:id/members/:userId",
  validate({ params: groupMemberParamsSchema }),
  controller.removeGroupMember,
);
api.post(
  "/:id/invitations",
  validate({ params: groupIdParamsSchema, body: inviteToGroupBodySchema }),
  controller.invite,
);
api.get(
  "/:id",
  validate({ params: groupIdParamsSchema }),
  controller.getById,
);
api.patch(
  "/:id",
  validate({ params: groupIdParamsSchema, body: updateGroupBodySchema }),
  controller.update,
);
api.delete(
  "/:id",
  validate({ params: groupIdParamsSchema }),
  controller.remove,
);

const router = Router();
router.use("/api/groups", api);

export default router;
