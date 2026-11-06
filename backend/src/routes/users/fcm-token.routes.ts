import { Router } from "express";
import { z } from "zod";
import type { NextFunction, Request, Response } from "express";
import { authMiddleware } from "../../middleware/auth.middleware.js";
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
 * Flutter ApiConstants.fcmToken = /api/user/fcm-token
 */
const api = Router();
api.use(authMiddleware);

api.post("/", validate({ body: bodySchema }), async (req, res, next) => {
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
});

api.delete("/", validate({ body: bodySchema }), async (req, res, next) => {
  try {
    if (!req.user?.uid) throw new UnauthorizedError();
    const data = await unregister.execute(req.user.uid, req.body.token);
    res.json({ success: true, data });
  } catch (error) {
    next(error);
  }
});

// Also accept token via query for DELETE clients that omit bodies.
api.delete(
  "/:token",
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

const router = Router();
router.use("/api/user/fcm-token", api);
export default router;
