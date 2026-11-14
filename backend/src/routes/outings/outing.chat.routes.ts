import { Router } from "express";
import { ChatController } from "../../controllers/chat/chat.controller.js";
import { validate } from "../../middleware/validate.middleware.js";
import {
  outingIdParamsSchema,
  messageParamsSchema, editMessageBodySchema,
  chatHistoryQuerySchema,
  sendMessageBodySchema,
} from "../../validators/chat/chat.validator.js";

/**
 * @openapi
 * /api/outings/{outingId}/messages:
 *   get:
 *     tags: [Outing Chat]
 *     summary: List outing messages
 *     description: >
 *       Participants can read history after the outing ends. For a bounded page,
 *       send limit and use next_cursor as before to request older messages.
 *     operationId: listOutingMessages
 *     parameters:
 *       - $ref: "#/components/parameters/ChatOutingId"
 *       - in: query
 *         name: limit
 *         schema: { type: integer, minimum: 1, maximum: 100 }
 *       - in: query
 *         name: before
 *         schema: { type: string, format: uuid }
 *       - in: query
 *         name: messageId
 *         description: Select one message in this outing. Omit before and limit when using this parameter.
 *         schema: { type: string, format: uuid }
 *     responses:
 *       "200":
 *         description: Messages ordered as stored
 *         content:
 *           application/json:
 *             schema:
 *               $ref: "#/components/schemas/ChatMessageListResponse"
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
 *   post:
 *     tags: [Outing Chat]
 *     summary: Send an outing message
 *     description: >
 *       The sender is the authenticated Firebase UID and must be the creator, a group member or an outing guest.
 *       Sending is allowed in draft, voting and confirmed states until scheduled_at plus two hours; afterwards 409 CHAT_CLOSED is returned.
 *       Pass clientMessageId to make retries idempotent. Stable mention tokens in text are validated against current chat participants and use canonical Neon display names. Mention notifications share one message/recipient event key and never notify the sender.
 *     operationId: sendOutingMessage
 *     parameters:
 *       - $ref: "#/components/parameters/ChatOutingId"
 *     requestBody:
 *       $ref: "#/components/requestBodies/SendMessage"
 *     responses:
 *       "201":
 *         description: Created message, or the stored message for a repeated clientMessageId
 *         content:
 *           application/json:
 *             schema:
 *               $ref: "#/components/schemas/ChatMessageResponse"
 *       "400":
 *         $ref: "#/components/responses/BadRequest"
 *       "401":
 *         $ref: "#/components/responses/Unauthorized"
 *       "403":
 *         $ref: "#/components/responses/Forbidden"
 *       "404":
 *         $ref: "#/components/responses/NotFound"
 *       "409":
 *         description: The outing is past, cancelled, or two hours beyond its scheduled start (CHAT_CLOSED)
 *         content:
 *           application/json:
 *             schema:
 *               $ref: "#/components/schemas/ErrorResponse"
 *       "500":
 *         $ref: "#/components/responses/InternalServerError"
 * /api/outings/{outingId}/read:
 *   patch:
 *     tags: [Outing Chat]
 *     summary: Mark outing chat as read
 *     description: >
 *       Upserts a `chat_reads` row for the authenticated participant so
 *       unread state can be derived from `last_read_at`. History remains
 *       readable after the outing ends.
 *     operationId: markOutingChatRead
 *     parameters:
 *       - $ref: "#/components/parameters/ChatOutingId"
 *     responses:
 *       "200":
 *         description: Updated chat read cursor
 *         content:
 *           application/json:
 *             schema:
 *               $ref: "#/components/schemas/ChatReadResponse"
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
/**
 * @openapi
 * /api/outings/{outingId}/messages/{messageId}:
 *   patch:
 *     tags: [Outing Chat]
 *     summary: Edit your own outing message
 *     operationId: editOutingMessage
 *     description: Authenticated current participants may mutate only their own messages while chat is open. Closed chats return 409 CHAT_CLOSED. Deletion retains an empty-text tombstone to preserve retry IDs and history cursors. Editing deleted messages returns 409 MESSAGE_DELETED. Editing is allowed only during the first 60 seconds after sent_at; at or after that instant it returns 409 MESSAGE_EDIT_WINDOW_EXPIRED. Deleting an own message is not subject to this edit-only window. Changes use the existing outing message socket event. Edits do not send new mention notifications.
 *     parameters:
 *       - $ref: "#/components/parameters/ChatOutingId"
 *       - in: path
 *         name: messageId
 *         required: true
 *         schema: { type: string, format: uuid }
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required: [text]
 *             properties:
 *               text: { type: string, minLength: 1, maxLength: 2000 }
 *     responses:
 *       "200":
 *         description: Canonical message (empty text for a deleted message)
 *         content:
 *           application/json:
 *             schema:
 *               $ref: "#/components/schemas/ChatMessageResponse"
 *       "400":
 *         $ref: "#/components/responses/BadRequest"
 *       "401":
 *         $ref: "#/components/responses/Unauthorized"
 *       "403":
 *         $ref: "#/components/responses/Forbidden"
 *       "404":
 *         $ref: "#/components/responses/NotFound"
 *       "409":
 *         description: CHAT_CLOSED, MESSAGE_DELETED or MESSAGE_EDIT_WINDOW_EXPIRED
 *         content:
 *           application/json:
 *             schema:
 *               $ref: "#/components/schemas/ErrorResponse"
 *   delete:
 *     tags: [Outing Chat]
 *     summary: Delete your own outing message
 *     operationId: deleteOutingMessage
 *     description: Authenticated current participants may mutate only their own messages while chat is open. Closed chats return 409 CHAT_CLOSED. Deletion retains an empty-text tombstone to preserve retry IDs and history cursors. Editing deleted messages returns 409 MESSAGE_DELETED. Editing is allowed only during the first 60 seconds after sent_at; at or after that instant it returns 409 MESSAGE_EDIT_WINDOW_EXPIRED. Deleting an own message is not subject to this edit-only window. Changes use the existing outing message socket event. Edits do not send new mention notifications.
 *     parameters:
 *       - $ref: "#/components/parameters/ChatOutingId"
 *       - in: path
 *         name: messageId
 *         required: true
 *         schema: { type: string, format: uuid }
 *     responses:
 *       "200":
 *         description: Canonical message (empty text for a deleted message)
 *         content:
 *           application/json:
 *             schema:
 *               $ref: "#/components/schemas/ChatMessageResponse"
 *       "400":
 *         $ref: "#/components/responses/BadRequest"
 *       "401":
 *         $ref: "#/components/responses/Unauthorized"
 *       "403":
 *         $ref: "#/components/responses/Forbidden"
 *       "404":
 *         $ref: "#/components/responses/NotFound"
 *       "409":
 *         description: CHAT_CLOSED, MESSAGE_DELETED or MESSAGE_EDIT_WINDOW_EXPIRED
 *         content:
 *           application/json:
 *             schema:
 *               $ref: "#/components/schemas/ErrorResponse"
 */
const router = Router();
const controller = new ChatController();

// Keep `:outingId` so ChatController / chat.validator stay unchanged.
router.get(
  "/:outingId/messages",
  validate({ params: outingIdParamsSchema, query: chatHistoryQuerySchema }),
  controller.listByOuting,
);
router.post(
  "/:outingId/messages",
  validate({
    params: outingIdParamsSchema,
    body: sendMessageBodySchema,
  }),
  controller.send,
);
router.patch(
  "/:outingId/read",
  validate({ params: outingIdParamsSchema }),
  controller.markAsRead,
);

router.patch("/:outingId/messages/:messageId", validate({ params: messageParamsSchema, body: editMessageBodySchema }), controller.mutate);
router.delete("/:outingId/messages/:messageId", validate({ params: messageParamsSchema }), controller.mutate);

export default router;
