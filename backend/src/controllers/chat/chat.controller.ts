import type { NextFunction, Request, Response } from "express";
import { ListMessagesUseCase } from "../../usecases/chat/list-messages.usecase.js";
import { SendMessageUseCase } from "../../usecases/chat/send-message.usecase.js";
import { UnauthorizedError } from "../../utils/errors.js";

export class ChatController {
  constructor(
    private readonly listMessages = new ListMessagesUseCase(),
    private readonly sendMessage = new SendMessageUseCase(),
  ) {}

  listByOuting = async (req: Request, res: Response, next: NextFunction) => {
    try {
      const messages = await this.listMessages.execute(
        req.params.outingId as string,
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
      });

      res.status(201).json({ success: true, data: message });
    } catch (error) {
      next(error);
    }
  };
}
