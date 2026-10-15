import { Router } from "express";
import chatRoutes from "./chat/chat.routes.js";
import groupRoutes from "./groups/group.routes.js";
import notificationRoutes from "./notifications/notification.routes.js";
import outingRoutes from "./outings/outing.routes.js";
import placeRoutes from "./places/place.routes.js";
import savedOutingRoutes from "./saved/saved.routes.js";
import userRoutes from "./users/user.routes.js";

const router = Router();

router.use(userRoutes);
router.use(groupRoutes);
router.use(savedOutingRoutes);
router.use(outingRoutes);
router.use(placeRoutes);
router.use(notificationRoutes);
router.use(chatRoutes);

export default router;
