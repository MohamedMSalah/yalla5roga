import { Router } from "express";
import authRoutes from "./auth/index.js";
import groupRoutes from "./groups/index.js";
import notificationRoutes from "./notifications/index.js";
import outingRoutes from "./outings/index.js";
import placeRoutes from "./places/index.js";
import userRoutes from "./users/index.js";

const router = Router();

// Mount order: feature indexes own static-before-dynamic registration.
router.use(authRoutes);
router.use(userRoutes);
router.use(groupRoutes);
router.use(outingRoutes);
router.use(placeRoutes);
router.use(notificationRoutes);

export default router;
