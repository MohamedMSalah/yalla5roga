import { Router } from "express";
import { NotificationController } from "../../controllers/notifications/notification.controller.js";
import { validate } from "../../middleware/validate.middleware.js";
import { notificationIdParamsSchema } from "../../validators/notifications/notification.validator.js";

/**
 * @openapi
 * /api/notifications:
 *   get:
 *     tags: [Notifications]
 *     summary: List notifications
 *     description: Returns notifications owned by the Firebase UID on the Bearer token.
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
 * /api/notifications/read:
 *   patch:
 *     tags: [Notifications]
 *     summary: Mark all notifications as read
 *     description: >
 *       Bulk-updates every unread notification owned by the Firebase UID on
 *       the Bearer token. Returns how many rows were changed.
 *     operationId: markAllNotificationsRead
 *     responses:
 *       "200":
 *         description: Bulk update result
 *         content:
 *           application/json:
 *             schema:
 *               $ref: "#/components/schemas/MarkAllNotificationsReadResponse"
 *       "401":
 *         $ref: "#/components/responses/Unauthorized"
 *       "500":
 *         $ref: "#/components/responses/InternalServerError"
 * /api/notifications/{id}/read:
 *   patch:
 *     tags: [Notifications]
 *     summary: Mark a notification as read
 *     description: >
 *       Marks the given notification as read. Allowed only when
 *       `notification.user_id` matches the Firebase UID on the Bearer token.
 *       Other users receive 403.
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
 *       "403":
 *         $ref: "#/components/responses/Forbidden"
 *       "404":
 *         $ref: "#/components/responses/NotFound"
 *       "500":
 *         $ref: "#/components/responses/InternalServerError"
 */
const router = Router();
const controller = new NotificationController();

// Static `/read` before `/:id/read`.
router.get("/", controller.list);
router.patch("/read", controller.markAllAsRead);
router.patch(
  "/:id/read",
  validate({ params: notificationIdParamsSchema }),
  controller.markAsRead,
);

export default router;
