import { Router } from "express";
import { authMiddleware } from "../../middleware/auth.middleware.js";
import notificationInboxRoutes from "./notification.inbox.routes.js";

const api = Router();
api.use(authMiddleware);
api.use(notificationInboxRoutes);

const router = Router();
router.use("/api/notifications", api);

export default router;
