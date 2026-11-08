import { Router } from "express";
import { authMiddleware } from "../../middleware/auth.middleware.js";
import userFcmRoutes from "./user.fcm.routes.js";
import userProfileRoutes from "./user.profile.routes.js";
import userSyncRoutes from "./user.sync.routes.js";

const api = Router();
api.use(authMiddleware);

// Static paths (sync, cuser/fcm-token, cuser) before dynamic /:id in profile.
api.use(userSyncRoutes);
api.use(userFcmRoutes);
api.use(userProfileRoutes);

const router = Router();
router.use("/api/users", api);

export default router;
