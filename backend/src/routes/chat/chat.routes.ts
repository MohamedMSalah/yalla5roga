import { Router } from "express";
import { ChatController } from "../../controllers/chat/chat.controller.js";
import { authMiddleware } from "../../middleware/auth.middleware.js";
import { validate } from "../../middleware/validate.middleware.js";
import {
  outingIdParamsSchema,
  sendMessageBodySchema,
} from "../../validators/chat/chat.validator.js";

/**
 * @openapi
 * /api/chat/outings/{outingId}/messages:
 *   get:
 *     tags: [Chat]
 *     summary: List outing messages
 *     description: >
 *       The caller must be the outing creator or an outing guest. History stays
 *       readable after the outing ends.
 *     operationId: listOutingMessages
 *     parameters:
 *       - $ref: "#/components/parameters/ChatOutingId"
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
 *     tags: [Chat]
 *     summary: Send an outing message
 *     description: >
 *       The sender is the authenticated Firebase UID and must be the creator or a guest.
 *       Sending is allowed only while the outing status is upcoming or voting; afterwards 409 CHAT_CLOSED is returned.
 *       Pass clientMessageId to make retries idempotent.
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
 */
const api = Router();
const controller = new ChatController();

api.use(authMiddleware);

api.get(
  "/outings/:outingId/messages",
  validate({ params: outingIdParamsSchema }),
  controller.listByOuting,
);
api.post(
  "/outings/:outingId/messages",
  validate({
    params: outingIdParamsSchema,
    body: sendMessageBodySchema,
  }),
  controller.send,
);

const router = Router();
router.use("/api/chat", api);

export default router;
