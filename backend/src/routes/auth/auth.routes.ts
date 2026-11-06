import { Router } from "express";
import { AuthController } from "../../controllers/auth/auth.controller.js";
import { validate } from "../../middleware/validate.middleware.js";
import {
  loginBodySchema,
  signupBodySchema,
} from "../../validators/auth/auth.validator.js";

/**
 * @openapi
 * /api/auth/login:
 *   post:
 *     tags: [Authentication]
 *     summary: Log in with email and password
 *     description: >
 *       Canonical email/password login. Verifies Neon `users.password_hash`,
 *       then returns a Firebase ID token session (via custom-token exchange)
 *       plus `customToken` so mobile clients can `signInWithCustomToken` and
 *       refresh ID tokens locally. Firebase Auth is not used for email passwords.
 *       Google, Apple, and phone OTP still use Firebase Auth on the client,
 *       then `POST /api/users/sync`.
 *     operationId: loginWithEmailPassword
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
 *     summary: Sign up with name, email, password, and phone
 *     description: >
 *       Canonical email/password signup. Hashes the password into Neon
 *       (`users.password_hash`), creates a Firebase Auth identity without a
 *       Firebase password, and returns `idToken` + `customToken` for the client
 *       session. Phone OTP may be verified on the client before calling this
 *       endpoint; Google/Apple continue to use Firebase then `POST /api/users/sync`.
 *     operationId: signupWithEmailPassword
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
 *         description: Email or phone is already in use
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

const router = Router();
router.use("/api/auth", api);

export default router;
