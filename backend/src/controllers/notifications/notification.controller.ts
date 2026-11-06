import type { NextFunction, Request, Response } from "express";
import { ListNotificationsUseCase } from "../../usecases/notifications/list-notifications.usecase.js";
import { MarkAllNotificationsReadUseCase } from "../../usecases/notifications/mark-all-notifications-read.usecase.js";
import { MarkNotificationReadUseCase } from "../../usecases/notifications/mark-notification-read.usecase.js";
import { UnauthorizedError } from "../../utils/errors.js";

export class NotificationController {
  constructor(
    private readonly listNotifications = new ListNotificationsUseCase(),
    private readonly markRead = new MarkNotificationReadUseCase(),
    private readonly markAllRead = new MarkAllNotificationsReadUseCase(),
  ) {}

  list = async (req: Request, res: Response, next: NextFunction) => {
    try {
      if (!req.user?.uid) throw new UnauthorizedError();

      const notifications = await this.listNotifications.execute(req.user.uid);
      res.json({ success: true, data: notifications });
    } catch (error) {
      next(error);
    }
  };

  markAsRead = async (req: Request, res: Response, next: NextFunction) => {
    try {
      if (!req.user?.uid) throw new UnauthorizedError();
      const notification = await this.markRead.execute(
        req.params.id as string,
        req.user.uid,
      );
      res.json({ success: true, data: notification });
    } catch (error) {
      next(error);
    }
  };

  markAllAsRead = async (req: Request, res: Response, next: NextFunction) => {
    try {
      if (!req.user?.uid) throw new UnauthorizedError();
      const result = await this.markAllRead.execute(req.user.uid);
      res.json({ success: true, data: result });
    } catch (error) {
      next(error);
    }
  };
}
