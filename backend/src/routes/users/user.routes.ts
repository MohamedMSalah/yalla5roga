import { Router } from "express";
import { UserController } from "../../controllers/users/user.controller.js";
import { authMiddleware } from "../../middleware/auth.middleware.js";
import { validate } from "../../middleware/validate.middleware.js";
import {
  syncUserBodySchema,
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
 * /api/users/sync:
 *   post:
 *     tags: [Users]
 *     summary: Sync a Firebase user into the database
 *     description: >
 *       Called after Firebase phone, Google, or Apple sign-in. The user id is
 *       the Firebase UID from the Bearer token. Do not send a password.
 *       First call creates a minimal profile from trusted token claims (and
 *       optional body bootstrap fields). Later calls return the existing
 *       profile without overwriting name, email, phone, or image_url from the
 *       body. A verified token phone may update the stored phone and claim
 *       invitations. Body phone is never treated as verified. Google and Apple
 *       accounts without a verified phone still receive a profile;
 *       `invitations.status` is then `phone_verification_required`. A verified
 *       phone already stored for a different user returns 409.
 *     operationId: syncUser
 *     requestBody:
 *       $ref: "#/components/requestBodies/SyncUser"
 *     responses:
 *       "200":
 *         description: Existing or newly created profile, plus invitation claim state
 *         content:
 *           application/json:
 *             schema:
 *               $ref: "#/components/schemas/SyncUserResponse"
 *       "400":
 *         $ref: "#/components/responses/BadRequest"
 *       "401":
 *         $ref: "#/components/responses/Unauthorized"
 *       "409":
 *         description: The verified phone number belongs to another account
 *         content:
 *           application/json:
 *             schema:
 *               $ref: "#/components/schemas/ErrorResponse"
 *       "500":
 *         $ref: "#/components/responses/InternalServerError"
 * /api/users:
 *   get:
 *     tags: [Users]
 *     summary: List users
 *     description: Returns all user profiles. Requires a valid Firebase ID token.
 *     operationId: listUsers
 *     responses:
 *       "200":
 *         description: All user profiles
 *         content:
 *           application/json:
 *             schema:
 *               $ref: "#/components/schemas/UserListResponse"
 *       "401":
 *         $ref: "#/components/responses/Unauthorized"
 *       "500":
 *         $ref: "#/components/responses/InternalServerError"
 * /api/users/{id}:
 *   get:
 *     tags: [Users]
 *     summary: Get a user by id
 *     description: Returns the profile for the given Firebase UID.
 *     operationId: getUser
 *     parameters:
 *       - $ref: "#/components/parameters/UserId"
 *     responses:
 *       "200":
 *         description: Matching user profile
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
const api = Router();
const controller = new UserController();

api.use(authMiddleware);

// Static paths before /:id so "cuser" and "sync" are never treated as user ids.
api.get("/cuser", controller.getCuser);
api.patch(
  "/cuser",
  validate({ body: updateUserBodySchema }),
  controller.updateCuser,
);
api.delete("/cuser", controller.deleteCuser);
api.post(
  "/sync",
  validate({ body: syncUserBodySchema }),
  controller.sync,
);
api.get("/", controller.list);
api.get(
  "/:id",
  validate({ params: userIdParamsSchema }),
  controller.getById,
);
api.delete(
  "/:id",
  validate({ params: userIdParamsSchema }),
  controller.deleteById,
);

const router = Router();
router.use("/api/users", api);

export default router;
