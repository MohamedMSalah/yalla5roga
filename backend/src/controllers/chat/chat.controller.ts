import { chatHistoryQuerySchema } from "../../validators/chat/chat.validator.js";
import type { NextFunction, Request, Response } from "express";
import { ListMessagesUseCase } from "../../usecases/chat/list-messages.usecase.js";
import { MarkChatReadUseCase } from "../../usecases/chat/mark-chat-read.usecase.js";
import { SendMessageUseCase } from "../../usecases/chat/send-message.usecase.js";
import { UnauthorizedError } from "../../utils/errors.js";
import { MutateMessageUseCase } from "../../usecases/chat/mutate-message.usecase.js";

export class ChatController {
  mutate = async (req: Request, res: Response, next: NextFunction) => {
    try {
      if (!req.user?.uid) throw new UnauthorizedError();
      const message = await new MutateMessageUseCase().execute(
        req.params.outingId as string, req.params.messageId as string,
        req.user.uid, req.method === "DELETE" ? null : req.body.text,
      );
      res.json({ success: true, data: message });
    } catch (error) { next(error); }
  };
  constructor(
    private readonly listMessages = new ListMessagesUseCase(),
    private readonly sendMessage = new SendMessageUseCase(),
    private readonly markRead = new MarkChatReadUseCase(),
  ) {}

  listByOuting = async (req: Request, res: Response, next: NextFunction) => {
    try {
      if (!req.user?.uid) throw new UnauthorizedError();

      const { before, limit, messageId } = chatHistoryQuerySchema.parse(req.query);
      const outingId = req.params.outingId as string;
      if (messageId) {
        const message = await this.listMessages.getMessage(outingId, req.user.uid, messageId);
        res.json({ success: true, data: [message], next_cursor: null });
        return;
      }
      const pageSize = limit ?? (before ? 40 : null);
      const messages = await this.listMessages.execute(
        outingId,
        req.user.uid,
        pageSize == null ? undefined : { before, limit: pageSize + 1 },
      );
      const hasMore = pageSize != null && messages.length > pageSize;
      const data = hasMore ? messages.slice(1) : messages;
      res.json({ success: true, data, next_cursor: hasMore ? data[0]?.id : null });
    } catch (error) {
      next(error);
    }
  };

  send = async (req: Request, res: Response, next: NextFunction) => {
    try {
      if (!req.user?.uid) throw new UnauthorizedError();

      const message = await this.sendMessage.execute({
        outing_id: req.params.outingId as string,
        sender_id: req.user.uid,
        text: req.body.text,
        client_message_id: req.body.clientMessageId ?? null,
      });

      res.status(201).json({ success: true, data: message });
    } catch (error) {
      next(error);
    }
  };

  markAsRead = async (req: Request, res: Response, next: NextFunction) => {
    try {
      if (!req.user?.uid) throw new UnauthorizedError();

      const read = await this.markRead.execute(
        req.params.outingId as string,
        req.user.uid,
      );
      res.json({ success: true, data: read });
    } catch (error) {
      next(error);
    }
  };
}
