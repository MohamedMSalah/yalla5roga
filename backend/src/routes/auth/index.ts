import { Router, type RequestHandler } from "express";
import { AuthController } from "../../controllers/auth/auth.controller.js";
import { authMiddleware } from "../../middleware/auth.middleware.js";
import { validate } from "../../middleware/validate.middleware.js";
import {
  changePasswordBodySchema,
  recoveryStartBodySchema, recoveryVerifyBodySchema, resetPasswordBodySchema,
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
 *       `password_hash` in Neon. The API verifies a recent Firebase phone OTP
 *       ID token, requires its phone to match the request, and keeps its UID.
 *       The result includes an application session via Firebase custom tokens.
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
 *       "401":
 *         $ref: "#/components/responses/Unauthorized"
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
 *         content:
 *           application/json:
 *             schema:
 *               $ref: "#/components/schemas/PasswordUpdateResponse"
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
 *         content:
 *           application/json:
 *             schema:
 *               $ref: "#/components/schemas/PasswordVerificationResponse"
 *       "400":
 *         $ref: "#/components/responses/BadRequest"
 *       "401":
 *         $ref: "#/components/responses/Unauthorized"
 */
export function createAuthRouter(controller = new AuthController()) {
  const api = Router();
  const attemptLimit = 20;
  const windowMs = 60_000;
  const attempts = new Map<string, number>();
  let windowEnds = 0;

  const limitCredentialAttempts: RequestHandler = (req, res, next) => {
    const now = Date.now();
    if (now >= windowEnds) {
      attempts.clear();
      windowEnds = now + windowMs;
    }
    const address = req.ip ?? req.socket.remoteAddress ?? "unknown";
    const count = attempts.get(address) ?? 0;
    if (count >= attemptLimit || (count === 0 && attempts.size >= 10_000)) {
      res.set("Retry-After", String(Math.ceil((windowEnds - now) / 1000)));
      res.status(429).json({ success: false, message: "Too many authentication attempts" });
      return;
    }
    attempts.set(address, count + 1);
    next();
  };

  api.post(
    "/login",
    limitCredentialAttempts,
    validate({ body: loginBodySchema }),
    controller.loginHandler,
  );
  api.post(
    "/signup",
    limitCredentialAttempts,
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

  api.post("/recovery/start", controller.recoveryLimit, validate({ body: recoveryStartBodySchema }), controller.recoveryStartHandler);
  api.post("/recovery/verify", controller.recoveryLimit, validate({ body: recoveryVerifyBodySchema }), controller.recoveryVerifyHandler);
  api.post("/recovery/reset", controller.recoveryLimit, validate({ body: resetPasswordBodySchema }), controller.recoveryResetHandler);

  const router = Router();
  router.use("/api/auth", api);

  return router;
}

export default createAuthRouter();

/**
 * @openapi
 * /api/auth/recovery/start:
 *   post:
 *     tags: [Authentication]
 *     operationId: startPasswordRecovery
 *     summary: Start recovery for an existing verified phone
 *     security: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             additionalProperties: false
 *             required: [phone]
 *             properties:
 *               phone: { type: string }
 *     responses:
 *       "200":
 *         description: Recovery step succeeded. Keep secrets in memory only. Response is no-store.
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               required: [success, data]
 *               properties:
 *                 success: { type: boolean }
 *                 data:
 *                   type: object
 *                   required: [requestToken, expiresIn, resendAfter]
 *                   properties:
 *                     requestToken: { type: string }
 *                     expiresIn: { type: integer, example: 600 }
 *                     resendAfter: { type: integer, example: 60 }
 *       "400":
 *         $ref: "#/components/responses/BadRequest"
 *       "401":
 *         $ref: "#/components/responses/Unauthorized"
 *       "429":
 *         description: Too many attempts or resend cooldown active
 *       "500":
 *         $ref: "#/components/responses/InternalServerError"
 */

/**
 * @openapi
 * /api/auth/recovery/verify:
 *   post:
 *     tags: [Authentication]
 *     operationId: verifyPasswordRecovery
 *     summary: Exchange fresh Firebase phone proof for single-use reset authorization
 *     security: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             additionalProperties: false
 *             required: [requestToken, phoneVerificationToken]
 *             properties:
 *               requestToken: { type: string, minLength: 43, maxLength: 43 }
 *               phoneVerificationToken: { type: string, maxLength: 10000 }
 *     responses:
 *       "200":
 *         description: Recovery step succeeded. Keep secrets in memory only. Response is no-store.
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               required: [success, data]
 *               properties:
 *                 success: { type: boolean }
 *                 data:
 *                   type: object
 *                   required: [resetToken, expiresIn]
 *                   properties:
 *                     resetToken: { type: string }
 *                     expiresIn: { type: integer, example: 300 }
 *       "400":
 *         $ref: "#/components/responses/BadRequest"
 *       "401":
 *         $ref: "#/components/responses/Unauthorized"
 *       "429":
 *         description: Too many attempts or resend cooldown active
 *       "500":
 *         $ref: "#/components/responses/InternalServerError"
 */

/**
 * @openapi
 * /api/auth/recovery/reset:
 *   post:
 *     tags: [Authentication]
 *     operationId: resetRecoveredPassword
 *     summary: Consume authorization and atomically update existing Neon password
 *     security: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             additionalProperties: false
 *             required: [resetToken, newPassword, confirmPassword]
 *             properties:
 *               resetToken: { type: string, minLength: 43, maxLength: 43 }
 *               newPassword: { type: string, minLength: 8, maxLength: 72, description: "Maximum 72 UTF-8 bytes; uppercase, lowercase, digit and symbol required" }
 *               confirmPassword: { type: string, minLength: 6, maxLength: 72 }
 *     responses:
 *       "200":
 *         description: Recovery step succeeded. Keep secrets in memory only. Response is no-store.
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               required: [success, data]
 *               properties:
 *                 success: { type: boolean }
 *                 data:
 *                   type: object
 *                   required: [updated]
 *                   properties:
 *                     updated: { type: boolean, example: true }
 *       "400":
 *         $ref: "#/components/responses/BadRequest"
 *       "401":
 *         $ref: "#/components/responses/Unauthorized"
 *       "429":
 *         description: Too many attempts or resend cooldown active
 *       "500":
 *         $ref: "#/components/responses/InternalServerError"
 */
