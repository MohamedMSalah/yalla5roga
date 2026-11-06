import { Router } from "express";
import authRoutes from "./auth/auth.routes.js";
import chatRoutes from "./chat/chat.routes.js";
import groupRoutes from "./groups/group.routes.js";
import notificationRoutes from "./notifications/notification.routes.js";
import outingRoutes from "./outings/outing.routes.js";
import placeRoutes from "./places/place.routes.js";
import savedOutingRoutes from "./saved/saved.routes.js";
import fcmTokenRoutes from "./users/fcm-token.routes.js";
import userRoutes from "./users/user.routes.js";

const router = Router();

// Mount order follows Swagger sections. Saved outings are registered before
// outing CRUD so `/api/outings/saved` is never captured by `/api/outings/:id`.
router.use(authRoutes);
router.use(userRoutes);
router.use(fcmTokenRoutes);
router.use(groupRoutes);
router.use(savedOutingRoutes);
router.use(outingRoutes);
router.use(placeRoutes);
router.use(notificationRoutes);
router.use(chatRoutes);

export default router;
