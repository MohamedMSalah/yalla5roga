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
 *     summary: List messages for an outing
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
 *       "500":
 *         $ref: "#/components/responses/InternalServerError"
 *   post:
 *     tags: [Chat]
 *     summary: Send a message in an outing chat
 *     description: The sender is the authenticated Firebase UID.
 *     operationId: sendOutingMessage
 *     parameters:
 *       - $ref: "#/components/parameters/ChatOutingId"
 *     requestBody:
 *       $ref: "#/components/requestBodies/SendMessage"
 *     responses:
 *       "201":
 *         description: Created message
 *         content:
 *           application/json:
 *             schema:
 *               $ref: "#/components/schemas/ChatMessageResponse"
 *       "400":
 *         $ref: "#/components/responses/BadRequest"
 *       "401":
 *         $ref: "#/components/responses/Unauthorized"
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
