import { Router } from "express";
import { GroupController } from "../../controllers/groups/group.controller.js";
import { validate } from "../../middleware/validate.middleware.js";
import {
  createGroupBodySchema,
  groupIdParamsSchema,
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
 *       Lists only the authenticated user’s memberships. If supplied, userId
 *       must match that caller’s Firebase UID.
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
 *         description: Groups for the authenticated user
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
 *       "403":
 *         $ref: "#/components/responses/Forbidden"
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
 *     description: Returns the group and caller role to an active group member.
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
 *       "403":
 *         $ref: "#/components/responses/Forbidden"
 *   patch:
 *     tags: [Groups]
 *     summary: Update a group
 *     description: >
 *       Updates group fields for the given UUID. Allowed only for members with
 *       `role = owner`. Other authenticated users receive 403.
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
 *       "403":
 *         $ref: "#/components/responses/Forbidden"
 *       "404":
 *         $ref: "#/components/responses/NotFound"
 *       "500":
 *         $ref: "#/components/responses/InternalServerError"
 *   delete:
 *     tags: [Groups]
 *     summary: Delete a group
 *     description: >
 *       Deletes the group with the given UUID. Allowed only for members with
 *       `role = owner`. Other authenticated users receive 403.
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
 *       "403":
 *         $ref: "#/components/responses/Forbidden"
 *       "404":
 *         $ref: "#/components/responses/NotFound"
 *       "500":
 *         $ref: "#/components/responses/InternalServerError"
 *       "409":
 *         description: The group still has outings
 *         content:
 *           application/json:
 *             schema:
 *               $ref: "#/components/schemas/ErrorResponse"
 */
const router = Router();
const controller = new GroupController();

// Static `/cuser` before `/:id`.
router.get("/cuser", controller.listForCuser);
router.get(
  "/",
  validate({ query: listGroupsQuerySchema }),
  controller.list,
);
router.post(
  "/",
  validate({ body: createGroupBodySchema }),
  controller.create,
);
router.get(
  "/:id",
  validate({ params: groupIdParamsSchema }),
  controller.getById,
);
router.patch(
  "/:id",
  validate({ params: groupIdParamsSchema, body: updateGroupBodySchema }),
  controller.update,
);
router.delete(
  "/:id",
  validate({ params: groupIdParamsSchema }),
  controller.remove,
);

export default router;
