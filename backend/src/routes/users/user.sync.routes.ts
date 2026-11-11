import { Router } from "express";
import { UserController } from "../../controllers/users/user.controller.js";
import { validate } from "../../middleware/validate.middleware.js";
import { syncUserBodySchema } from "../../validators/users/user.validator.js";

/**
 * @openapi
 * /api/users/sync:
 *   post:
 *     tags: [Users]
 *     summary: Sync a Firebase user into the database (canonical provisioning)
 *     description: >
 *       Use a Firebase phone OTP or phone/password session ID token as Bearer.
 *       The token UID identifies the Neon profile. A verified Firebase phone
 *       may update the stored number and claim invitations. Existing display
 *       fields are edited through PATCH /api/users/cuser. A verified phone
 *       already stored for a different user returns 409.
 *       Optional phoneVerificationToken is a recent phone OTP ID token. It can
 *       rebind a phone credential from an unused OTP UID to the Bearer UID;
 *       another registered identity is never merged. Claims invitations in
 *       the same sync request after verification. An OTP-authenticated caller can
 *       create a profile here and later enroll a password through POST /api/auth/signup.
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
 */
const router = Router();
const controller = new UserController();

// Static `/sync` must register before `/:id`.
router.post(
  "/sync",
  validate({ body: syncUserBodySchema }),
  controller.sync,
);

export default router;
