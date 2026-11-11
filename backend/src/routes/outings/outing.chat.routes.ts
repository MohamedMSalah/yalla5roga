import { Router } from "express";
import { ChatController } from "../../controllers/chat/chat.controller.js";
import { validate } from "../../middleware/validate.middleware.js";
import {
  outingIdParamsSchema,
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
 *       Sending is allowed in draft, voting and confirmed states; afterwards 409 CHAT_CLOSED is returned.
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
 *         description: The outing is past or cancelled, so the chat is closed (CHAT_CLOSED)
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

export default router;
