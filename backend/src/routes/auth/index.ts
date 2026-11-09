import { Router } from "express";
import { AuthController } from "../../controllers/auth/auth.controller.js";
import { authMiddleware } from "../../middleware/auth.middleware.js";
import { validate } from "../../middleware/validate.middleware.js";
import {
  changePasswordBodySchema,
  loginBodySchema,
  signupBodySchema,
  verifyPasswordBodySchema,
} from "../../validators/auth/auth.validator.js";

/**
 * @openapi
 * /api/auth/login:
 *   post:
 *     tags: [Authentication]
 *     summary: Log in with phone number and password
 *     description: >
 *       Canonical phone/password login. Verifies Neon `users.password_hash`,
 *       then returns a Firebase ID token session (via custom-token exchange)
 *       plus `customToken` so mobile clients can `signInWithCustomToken` and
 *       refresh ID tokens locally. Firebase Auth is not used for application passwords.
 *     operationId: loginWithPhonePassword
 *     security: []
 *     requestBody:
 *       $ref: "#/components/requestBodies/Login"
 *     responses:
 *       "200":
 *         description: Firebase session, including the ID token
 *         content:
 *           application/json:
 *             schema:
 *               $ref: "#/components/schemas/AuthSessionResponse"
 *       "400":
 *         $ref: "#/components/responses/BadRequest"
 *       "401":
 *         $ref: "#/components/responses/Unauthorized"
 *       "429":
 *         description: Too many attempts
 *         content:
 *           application/json:
 *             schema:
 *               $ref: "#/components/schemas/ErrorResponse"
 *       "500":
 *         $ref: "#/components/responses/InternalServerError"
 * /api/auth/signup:
 *   post:
 *     tags: [Authentication]
 *     summary: Sign up with name, phone number, and password
 *     description: >
 *       Canonical phone/password signup. Stores name, phone, and
 *       `password_hash` in Neon only. Creates a bare Firebase Auth UID (no
 *       profile fields or password in Firebase) so the API can mint
 *       ID tokens, then returns `idToken` + `customToken`. The Flutter app
 *       verifies the supplied phone by OTP before calling this endpoint.
 *     operationId: signupWithPhonePassword
 *     security: []
 *     requestBody:
 *       $ref: "#/components/requestBodies/Signup"
 *     responses:
 *       "201":
 *         description: Created account and Firebase session
 *         content:
 *           application/json:
 *             schema:
 *               $ref: "#/components/schemas/AuthSessionResponse"
 *       "400":
 *         $ref: "#/components/responses/BadRequest"
 *       "409":
 *         description: Phone number is already in use
 *         content:
 *           application/json:
 *             schema:
 *               $ref: "#/components/schemas/ErrorResponse"
 *       "429":
 *         description: Too many attempts
 *         content:
 *           application/json:
 *             schema:
 *               $ref: "#/components/schemas/ErrorResponse"
 *       "500":
 *         $ref: "#/components/responses/InternalServerError"
 * /api/auth/change-password:
 *   post:
 *     tags: [Authentication]
 *     summary: Change Neon password
 *     description: >
 *       Authenticated. Verifies `currentPassword` against Neon `password_hash`
 *       and stores a new bcrypt hash. Firebase Auth is not updated (identity-only).
 *     operationId: changePassword
 *     security:
 *       - bearerAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required: [currentPassword, newPassword]
 *             properties:
 *               currentPassword: { type: string, minLength: 6, maxLength: 128 }
 *               newPassword: { type: string, minLength: 6, maxLength: 128 }
 *     responses:
 *       "200":
 *         description: Password updated
 *       "400":
 *         $ref: "#/components/responses/BadRequest"
 *       "401":
 *         $ref: "#/components/responses/Unauthorized"
 * /api/auth/verify-password:
 *   post:
 *     tags: [Authentication]
 *     summary: Confirm current Neon password
 *     description: >
 *       Authenticated. Verifies the caller's Neon password without changing it.
 *       Used by profile flows that require recent password confirmation.
 *     operationId: verifyPassword
 *     security:
 *       - bearerAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required: [password]
 *             properties:
 *               password: { type: string, minLength: 6, maxLength: 128 }
 *     responses:
 *       "200":
 *         description: Password verified
 *       "400":
 *         $ref: "#/components/responses/BadRequest"
 *       "401":
 *         $ref: "#/components/responses/Unauthorized"
 */
const api = Router();
const controller = new AuthController();

api.post(
  "/login",
  validate({ body: loginBodySchema }),
  controller.loginHandler,
);
api.post(
  "/signup",
  validate({ body: signupBodySchema }),
  controller.signupHandler,
);
api.post(
  "/change-password",
  authMiddleware,
  validate({ body: changePasswordBodySchema }),
  controller.changePasswordHandler,
);
api.post(
  "/verify-password",
  authMiddleware,
  validate({ body: verifyPasswordBodySchema }),
  controller.verifyPasswordHandler,
);

const router = Router();
router.use("/api/auth", api);

export default router;
