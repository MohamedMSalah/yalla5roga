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
 *     description: >
 *       Returns notifications owned by the Firebase UID on the Bearer token.
 *       Returns a bounded newest-first page (default 20, maximum 100).
 *       Pass pagination.nextCursor as cursor to fetch older rows.
 *       The data array and next_cursor compatibility alias are preserved.
 *     operationId: listNotifications
 *     parameters:
 *       - in: query
 *         name: limit
 *         required: false
 *         schema: { type: integer, minimum: 1, maximum: 100, default: 20 }
 *       - in: query
 *         name: cursor
 *         required: false
 *         schema: { type: string }
 *         description: "The next_cursor value from the previous page."
 *     responses:
 *       "200":
 *         description: Notifications owned by the Firebase UID on the token
 *         content:
 *           application/json:
 *             schema:
 *               $ref: "#/components/schemas/NotificationListResponse"
 *       "400":
 *         $ref: "#/components/responses/BadRequest"
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
router.get("/preferences", controller.preferences);
router.patch("/preferences", controller.updatePreferences);
router.get(
  "/:id/system-payload",
  validate({ params: notificationIdParamsSchema }),
  controller.systemPayload,
);
router.patch(
  "/:id/read",
  validate({ params: notificationIdParamsSchema }),
  controller.markAsRead,
);

export default router;

/**
 * @openapi
 * /api/notifications/preferences:
 *   get:
 *     tags: [Notifications]
 *     operationId: getNotificationPreferences
 *     summary: Get the caller's system push preferences
 *     responses:
 *       "200":
 *         description: Boolean preferences; lockScreenPreview defaults false
 *         content:
 *           application/json:
 *             schema: { $ref: "#/components/schemas/NotificationPreferencesResponse" }
 *       "401": { $ref: "#/components/responses/Unauthorized" }
 *       "404": { $ref: "#/components/responses/NotFound" }
 *       "500": { $ref: "#/components/responses/InternalServerError" }
 *   patch:
 *     tags: [Notifications]
 *     operationId: updateNotificationPreferences
 *     summary: Update the caller's system push preferences without removing inbox history
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             additionalProperties: false
 *             properties:
 *               pushEnabled: { type: boolean }
 *               chatMessages: { type: boolean }
 *               mentions: { type: boolean }
 *               mentionPriority: { type: boolean }
 *               groupEvents: { type: boolean }
 *               outings: { type: boolean }
 *               voting: { type: boolean }
 *               reminders: { type: boolean }
 *               attendance: { type: boolean }
 *               lockScreenPreview: { type: boolean }
 *     responses:
 *       "200":
 *         description: Persisted preferences
 *         content:
 *           application/json:
 *             schema: { $ref: "#/components/schemas/NotificationPreferencesResponse" }
 *       "400": { $ref: "#/components/responses/BadRequest" }
 *       "401": { $ref: "#/components/responses/Unauthorized" }
 *       "404": { $ref: "#/components/responses/NotFound" }
 *       "500": { $ref: "#/components/responses/InternalServerError" }
 * /api/notifications/{id}/system-payload:
 *   get:
 *     tags: [Notifications]
 *     operationId: getNotificationSystemPayload
 *     summary: Resolve current authorized system display data
 *     description: "No-store. Returns {success,data:{available,payload}}. Read, deleted, inaccessible, expired or preference-disabled notifications have available=false and payload=null. Does not mark read."
 *     parameters:
 *       - $ref: "#/components/parameters/UuidId"
 *     responses:
 *       "200":
 *         description: Current display metadata or unavailable
 *         content:
 *           application/json:
 *             schema: { $ref: "#/components/schemas/NotificationSystemPayloadResponse" }
 *       "400": { $ref: "#/components/responses/BadRequest" }
 *       "401": { $ref: "#/components/responses/Unauthorized" }
 *       "403": { $ref: "#/components/responses/Forbidden" }
 *       "404": { $ref: "#/components/responses/NotFound" }
 *       "500": { $ref: "#/components/responses/InternalServerError" }
 */
