import { Router } from "express";
import { mountRoutes } from "../../monitoring/routes.js";
import { authMiddleware } from "../../middleware/auth.middleware.js";
import userFcmRoutes from "./user.fcm.routes.js";
import userProfileRoutes from "./user.profile.routes.js";
import userSavedLocationRoutes from "./user.saved-location.routes.js";
import userLocationPrivacyRoutes from "./user.location-privacy.routes.js";
import userTransportationRoutes from "./user.transportation.routes.js";
import userSyncRoutes from "./user.sync.routes.js";

const api = Router();
api.use(authMiddleware);

// Static paths (sync, cuser/fcm-token, cuser) before dynamic /:id in profile.
api.use(userSyncRoutes);
api.use(userFcmRoutes);
api.use(userSavedLocationRoutes);
api.use(userLocationPrivacyRoutes);
api.use(userTransportationRoutes);
api.use(userProfileRoutes);

const router = Router();
mountRoutes(router, "/api/users", api);

export default router;
