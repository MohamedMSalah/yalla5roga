import { Router } from "express";
import { NotificationController } from "../../controllers/notifications/notification.controller.js";
import { authMiddleware } from "../../middleware/auth.middleware.js";
import { validate } from "../../middleware/validate.middleware.js";
import { notificationIdParamsSchema } from "../../validators/notifications/notification.validator.js";

/**
 * @openapi
 * /api/notifications:
 *   get:
 *     tags: [Notifications]
 *     summary: List notifications for the authenticated user
 *     operationId: listNotifications
 *     responses:
 *       "200":
 *         description: Notifications owned by the Firebase UID on the token
 *         content:
 *           application/json:
 *             schema:
 *               $ref: "#/components/schemas/NotificationListResponse"
 *       "401":
 *         $ref: "#/components/responses/Unauthorized"
 *       "500":
 *         $ref: "#/components/responses/InternalServerError"
 * /api/notifications/{id}/read:
 *   patch:
 *     tags: [Notifications]
 *     summary: Mark a notification as read
 *     operationId: markNotificationRead
 *     parameters:
 *       - $ref: "#/components/parameters/UuidId"
 *     responses:
 *       "200":
 *         description: Updated notification
 *         content:
 *           application/json:
 *             schema:
 *               $ref: "#/components/schemas/NotificationResponse"
 *       "400":
 *         $ref: "#/components/responses/BadRequest"
 *       "401":
 *         $ref: "#/components/responses/Unauthorized"
 *       "404":
 *         $ref: "#/components/responses/NotFound"
 *       "500":
 *         $ref: "#/components/responses/InternalServerError"
 */
const api = Router();
const controller = new NotificationController();

api.use(authMiddleware);

api.get("/", controller.list);
api.patch(
  "/:id/read",
  validate({ params: notificationIdParamsSchema }),
  controller.markAsRead,
);

const router = Router();
router.use("/api/notifications", api);

export default router;
