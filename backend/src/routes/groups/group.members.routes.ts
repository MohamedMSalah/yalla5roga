import { Router } from "express";
import { GroupController } from "../../controllers/groups/group.controller.js";
import { validate } from "../../middleware/validate.middleware.js";
import {
  addGroupMemberBodySchema,
  groupIdParamsSchema,
  groupMemberParamsSchema,
} from "../../validators/groups/group.validator.js";

/**
 * @openapi
 * /api/groups/{id}/members:
 *   get:
 *     tags: [Group Members]
 *     summary: List group members
 *     description: Returns active member profiles in data and phone associations awaiting registration in pending_members. Only active members can read the roster.
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
 *       "403":
 *         $ref: "#/components/responses/Forbidden"
 *   post:
 *     tags: [Group Members]
 *     summary: Add a group member by phone number
 *     description: >
 *       Adds an existing user to the group using their phone number.
 *       Allowed only for members with `role = owner`. Any member may still
 *       invite via `POST /api/groups/{id}/invitations`.
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
 *       "403":
 *         $ref: "#/components/responses/Forbidden"
 *       "404":
 *         $ref: "#/components/responses/NotFound"
 *       "500":
 *         $ref: "#/components/responses/InternalServerError"
 *       "409":
 *         description: The request conflicts with the current resource state
 *         content:
 *           application/json:
 *             schema:
 *               $ref: "#/components/schemas/ErrorResponse"
 * /api/groups/{id}/members/{userId}:
 *   delete:
 *     tags: [Group Members]
 *     summary: Remove a group member
 *     description: >
 *       Removes the given user from the group. Allowed only for members with
 *       `role = owner`. Removing the last remaining owner is forbidden (403).
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
 *       "403":
 *         $ref: "#/components/responses/Forbidden"
 *       "404":
 *         $ref: "#/components/responses/NotFound"
 *       "500":
 *         $ref: "#/components/responses/InternalServerError"
 */
const router = Router();
const controller = new GroupController();

router.get(
  "/:id/members",
  validate({ params: groupIdParamsSchema }),
  controller.members,
);
router.post(
  "/:id/members",
  validate({ params: groupIdParamsSchema, body: addGroupMemberBodySchema }),
  controller.addGroupMember,
);
router.delete(
  "/:id/members/:userId",
  validate({ params: groupMemberParamsSchema }),
  controller.removeGroupMember,
);

export default router;
