import { Router } from "express";
import type { NextFunction, Request, Response } from "express";
import { z } from "zod";
import { validate } from "../../middleware/validate.middleware.js";
import {
  RegisterFcmTokenUseCase,
  UnregisterFcmTokenUseCase,
} from "../../usecases/users/fcm-token.usecase.js";
import { UnauthorizedError } from "../../utils/errors.js";

const bodySchema = z.object({
  token: z.string().trim().min(10).max(512),
  platform: z.string().trim().max(20).optional().nullable(),
});

const register = new RegisterFcmTokenUseCase();
const unregister = new UnregisterFcmTokenUseCase();

/**
 * @openapi
 * /api/users/cuser/fcm-token:
 *   post:
 *     tags: [Users]
 *     summary: Register an FCM device token
 *     description: >
 *       Binds the token to the Firebase UID on the Bearer token.
 *       Never trusts a client-supplied user id.
 *     operationId: registerFcmToken
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required: [token]
 *             properties:
 *               token:
 *                 type: string
 *                 minLength: 10
 *                 maxLength: 512
 *               platform:
 *                 type: string
 *                 maxLength: 20
 *                 nullable: true
 *     responses:
 *       "201":
 *         description: Token registered
 *         content:
 *           application/json:
 *             schema:
 *               $ref: "#/components/schemas/RegisteredFcmTokenResponse"
 *       "400":
 *         $ref: "#/components/responses/BadRequest"
 *       "401":
 *         $ref: "#/components/responses/Unauthorized"
 *       "500":
 *         $ref: "#/components/responses/InternalServerError"
 *   delete:
 *     tags: [Users]
 *     summary: Unregister an FCM device token
 *     description: >
 *       Removes the token for the Firebase UID on the Bearer token.
 *       Never trusts a client-supplied user id.
 *     operationId: unregisterFcmToken
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required: [token]
 *             properties:
 *               token:
 *                 type: string
 *                 minLength: 10
 *                 maxLength: 512
 *     responses:
 *       "200":
 *         description: Token unregistered
 *         content:
 *           application/json:
 *             schema:
 *               $ref: "#/components/schemas/UnregisteredFcmTokenResponse"
 *       "400":
 *         $ref: "#/components/responses/BadRequest"
 *       "401":
 *         $ref: "#/components/responses/Unauthorized"
 *       "500":
 *         $ref: "#/components/responses/InternalServerError"
 * /api/users/cuser/fcm-token/{token}:
 *   delete:
 *     tags: [Users]
 *     summary: Unregister an FCM device token via path
 *     description: >
 *       Same ownership rule as body DELETE — scopes to the Firebase UID on
 *       the Bearer token only.
 *     operationId: unregisterFcmTokenByPath
 *     parameters:
 *       - in: path
 *         name: token
 *         required: true
 *         schema:
 *           type: string
 *     responses:
 *       "200":
 *         description: Token unregistered
 *         content:
 *           application/json:
 *             schema:
 *               $ref: "#/components/schemas/UnregisteredFcmTokenResponse"
 *       "401":
 *         $ref: "#/components/responses/Unauthorized"
 *       "500":
 *         $ref: "#/components/responses/InternalServerError"
 */
const router = Router();

// Static `/cuser/fcm-token` before `/:id`.
router.post(
  "/cuser/fcm-token",
  validate({ body: bodySchema }),
  async (req, res, next) => {
    try {
      if (!req.user?.uid) throw new UnauthorizedError();
      const data = await register.execute(
        req.user.uid,
        req.body.token,
        req.body.platform,
      );
      res.status(201).json({ success: true, data });
    } catch (error) {
      next(error);
    }
  },
);

router.delete(
  "/cuser/fcm-token",
  validate({ body: bodySchema }),
  async (req, res, next) => {
    try {
      if (!req.user?.uid) throw new UnauthorizedError();
      const data = await unregister.execute(req.user.uid, req.body.token);
      res.json({ success: true, data });
    } catch (error) {
      next(error);
    }
  },
);

router.delete(
  "/cuser/fcm-token/:token",
  async (req: Request, res: Response, next: NextFunction) => {
    try {
      if (!req.user?.uid) throw new UnauthorizedError();
      const data = await unregister.execute(
        req.user.uid,
        decodeURIComponent(req.params.token as string),
      );
      res.json({ success: true, data });
    } catch (error) {
      next(error);
    }
  },
);

export default router;
