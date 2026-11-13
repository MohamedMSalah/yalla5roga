import { Router } from "express";
import { UserController } from "../../controllers/users/user.controller.js";
import { validate } from "../../middleware/validate.middleware.js";
import {
  updateUserBodySchema,
  userIdParamsSchema,
} from "../../validators/users/user.validator.js";

/**
 * @openapi
 * /api/users/cuser:
 *   get:
 *     tags: [Users]
 *     summary: Get the authenticated user
 *     description: >
 *       Returns the profile for the Firebase UID on the Bearer token.
 *       Returns 404 until a profile row exists (call sync or signup first).
 *     operationId: getCurrentUser
 *     responses:
 *       "200":
 *         description: Profile for the Firebase UID on the token
 *         content:
 *           application/json:
 *             schema:
 *               $ref: "#/components/schemas/UserResponse"
 *       "401":
 *         $ref: "#/components/responses/Unauthorized"
 *       "404":
 *         $ref: "#/components/responses/NotFound"
 *       "500":
 *         $ref: "#/components/responses/InternalServerError"
 *   patch:
 *     tags: [Users]
 *     summary: Update the authenticated user
 *     description: >
 *       Updates application profile fields for the Firebase UID on the Bearer
 *       token. Use this for profile completion and edits after Sync. UID, role,
 *       and other privileged fields cannot be changed. A phone in this body is
 *       not treated as Firebase-verified.
 *     operationId: updateCurrentUser
 *     requestBody:
 *       $ref: "#/components/requestBodies/UpdateUser"
 *     responses:
 *       "200":
 *         description: Updated profile
 *         content:
 *           application/json:
 *             schema:
 *               $ref: "#/components/schemas/UserResponse"
 *       "400":
 *         $ref: "#/components/responses/BadRequest"
 *       "401":
 *         $ref: "#/components/responses/Unauthorized"
 *       "404":
 *         $ref: "#/components/responses/NotFound"
 *       "500":
 *         $ref: "#/components/responses/InternalServerError"
 *   delete:
 *     tags: [Users]
 *     summary: Delete the authenticated user
 *     description: Deletes the profile that belongs to the Firebase UID on the Bearer token.
 *     operationId: deleteCurrentUser
 *     responses:
 *       "200":
 *         description: Deleted profile
 *         content:
 *           application/json:
 *             schema:
 *               $ref: "#/components/schemas/UserResponse"
 *       "401":
 *         $ref: "#/components/responses/Unauthorized"
 *       "404":
 *         $ref: "#/components/responses/NotFound"
 *       "500":
 *         $ref: "#/components/responses/InternalServerError"
 *       "409":
 *         description: The profile is still referenced by application records
 *         content:
 *           application/json:
 *             schema:
 *               $ref: "#/components/schemas/ErrorResponse"
 * /api/users:
 *   get:
 *     tags: [Users]
 *     summary: Find users by id or phone
 *     description: >
 *       Directory lookup for authorized member discovery. Supply `ids`
 *       (comma-separated Firebase UIDs, at most 100) or an exact `phone`.
 *       A bare request returns 400. The response omits phone numbers and
 *       credential state so the endpoint cannot enumerate profiles.
 *       A `phone` lookup only matches a profile that shares an active group
 *       with the caller; unrelated or unregistered numbers both return an
 *       empty list, so the endpoint is not a registration oracle. Phone-based
 *       invitations are resolved server-side by the group invitation endpoint.
 *     operationId: listUsers
 *     parameters:
 *       - in: query
 *         name: ids
 *         required: false
 *         schema: { type: string }
 *         description: Comma-separated Firebase UIDs. Maximum 100.
 *       - in: query
 *         name: phone
 *         required: false
 *         schema: { type: string, example: "+201001234567" }
 *         description: >
 *           Exact phone number, normalized to E.164. Matches only users who
 *           share an active group with the caller.
 *     responses:
 *       "200":
 *         description: Matching directory-safe profiles
 *         content:
 *           application/json:
 *             schema:
 *               $ref: "#/components/schemas/UserSummaryListResponse"
 *       "400":
 *         $ref: "#/components/responses/BadRequest"
 *       "401":
 *         $ref: "#/components/responses/Unauthorized"
 *       "500":
 *         $ref: "#/components/responses/InternalServerError"
 * /api/users/{id}:
 *   get:
 *     tags: [Users]
 *     summary: Get a user by id
 *     description: >
 *       When `{id}` is the authenticated Firebase UID, returns the same full
 *       profile as `GET /api/users/cuser` (including the caller's own phone and
 *       `has_password`). For any other user it returns the directory-safe
 *       summary only: `id`, `name`, `image_url`, and timestamps. Phone numbers,
 *       `has_password`, and other authentication fields are never exposed for
 *       another account. Authorized member phones come from the group roster
 *       endpoint, not this route.
 *     operationId: getUser
 *     parameters:
 *       - $ref: "#/components/parameters/UserId"
 *     responses:
 *       "200":
 *         description: Self profile, or directory-safe summary for another user
 *         content:
 *           application/json:
 *             schema:
 *               oneOf:
 *                 - $ref: "#/components/schemas/UserResponse"
 *                 - $ref: "#/components/schemas/UserSummaryResponse"
 *       "400":
 *         $ref: "#/components/responses/BadRequest"
 *       "401":
 *         $ref: "#/components/responses/Unauthorized"
 *       "404":
 *         $ref: "#/components/responses/NotFound"
 *       "500":
 *         $ref: "#/components/responses/InternalServerError"
 *   delete:
 *     tags: [Users]
 *     summary: Delete a user by id
 *     description: Allowed only when the path id matches the authenticated Firebase UID.
 *     operationId: deleteUser
 *     parameters:
 *       - $ref: "#/components/parameters/UserId"
 *     responses:
 *       "200":
 *         description: Deleted profile
 *         content:
 *           application/json:
 *             schema:
 *               $ref: "#/components/schemas/UserResponse"
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
const controller = new UserController();

// Static `/cuser` before `/:id`.
router.get("/cuser", controller.getCuser);
router.patch(
  "/cuser",
  validate({ body: updateUserBodySchema }),
  controller.updateCuser,
);
router.delete("/cuser", controller.deleteCuser);
router.get("/", controller.list);
router.get(
  "/:id",
  validate({ params: userIdParamsSchema }),
  controller.getById,
);
router.delete(
  "/:id",
  validate({ params: userIdParamsSchema }),
  controller.deleteById,
);

export default router;
