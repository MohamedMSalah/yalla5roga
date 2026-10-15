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
 * /api/users:
 *   get:
 *     tags: [Users]
 *     summary: List users
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
 * /api/users/cuser:
 *   get:
 *     tags: [Users]
 *     summary: Get the authenticated user
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
 *       the Firebase UID. Do not send a password. Phone is optional. Invitations
 *       are claimed only when the token contains a verified phone number.
 *       Google and Apple accounts without a verified phone still receive a
 *       profile. `invitations.status` is then `phone_verification_required`,
 *       which does not list invitations and does not block other features.
 *       A phone already stored for a different user returns 409 and is not merged.
 *     operationId: syncUser
 *     requestBody:
 *       $ref: "#/components/requestBodies/SyncUser"
 *     responses:
 *       "200":
 *         description: Created or updated profile, plus invitation claim state
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
 * /api/users/{id}:
 *   get:
 *     tags: [Users]
 *     summary: Get a user by id
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

api.get("/", controller.list);
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
