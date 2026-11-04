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
 *       Verifies the email and password against the Neon `users.password_hash`,
 *       then returns a Firebase ID token (via a custom token exchange) for use
 *       as `Authorization: Bearer <idToken>` on protected routes. Firebase is
 *       identity-only for this flow; credentials live in Neon.
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
 *       Hashes the password into Neon (`users.password_hash`), creates a
 *       Firebase Auth identity without a Firebase password, and returns a
 *       Firebase ID token. The phone is saved on the profile but is not treated
 *       as verified until Firebase phone auth succeeds. Google, Apple, and
 *       phone-only flows should use `POST /api/users/sync` after Firebase
 *       sign-in instead.
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
