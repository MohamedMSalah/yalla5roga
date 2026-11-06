import type { NextFunction, Request, Response } from "express";
import { ListMessagesUseCase } from "../../usecases/chat/list-messages.usecase.js";
import { MarkChatReadUseCase } from "../../usecases/chat/mark-chat-read.usecase.js";
import { SendMessageUseCase } from "../../usecases/chat/send-message.usecase.js";
import { UnauthorizedError } from "../../utils/errors.js";

export class ChatController {
  constructor(
    private readonly listMessages = new ListMessagesUseCase(),
    private readonly sendMessage = new SendMessageUseCase(),
    private readonly markRead = new MarkChatReadUseCase(),
  ) {}

  listByOuting = async (req: Request, res: Response, next: NextFunction) => {
    try {
      if (!req.user?.uid) throw new UnauthorizedError();

      const messages = await this.listMessages.execute(
        req.params.outingId as string,
        req.user.uid,
      );
      res.json({ success: true, data: messages });
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
