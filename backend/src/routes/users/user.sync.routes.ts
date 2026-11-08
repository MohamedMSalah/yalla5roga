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
 *       CANONICAL user provisioning after any Firebase sign-in (phone, Google,
 *       Apple, or Firebase email/password). The user id is the Firebase UID from
 *       the Bearer token. Do not send a password.
 *       First call creates a minimal profile from trusted token claims (and
 *       optional body bootstrap fields). Later calls return the existing
 *       profile without overwriting name, email, phone, or image_url from the
 *       body. A verified token phone may update the stored phone and claim
 *       invitations. Body phone is never treated as verified. Google and Apple
 *       accounts without a verified phone still receive a profile;
 *       `invitations.status` is then `phone_verification_required`. A verified
 *       phone already stored for a different user returns 409.
 *       Profile edits after sync use `PATCH /api/users/cuser`.
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
