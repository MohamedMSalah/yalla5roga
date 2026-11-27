import { Router } from "express";
import authRoutes from "./auth/index.js";
import groupRoutes from "./groups/index.js";
import meetupRoutes from "./meetups/meetup.routes.js";
import invitationRoutes from "./invitations/index.js";
import mediaRoutes from "./media/index.js";
import notificationRoutes from "./notifications/index.js";
import locationTravelNotificationRoutes from "./notifications/location-travel-notification.routes.js";
import outingRoutes from "./outings/index.js";
import placeRoutes from "./places/index.js";
import routingRoutes from "./routing.routes.js";
import startingLocationOverrideRoutes from "./users/starting-location-override.routes.js";
import userRoutes from "./users/index.js";

const router = Router();

// Mount order: feature indexes own static-before-dynamic registration.
router.use(authRoutes);
router.use(locationTravelNotificationRoutes);
router.use(userRoutes);
router.use(routingRoutes);
router.use(meetupRoutes);
router.use(startingLocationOverrideRoutes);
router.use(groupRoutes);
router.use(invitationRoutes);
router.use(outingRoutes);
router.use(placeRoutes);
router.use(notificationRoutes);
router.use(mediaRoutes);

export default router;
