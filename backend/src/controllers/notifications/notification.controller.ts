import type { NextFunction, Request, Response } from "express";
import { ListNotificationsUseCase } from "../../usecases/notifications/list-notifications.usecase.js";
import { MarkAllNotificationsReadUseCase } from "../../usecases/notifications/mark-all-notifications-read.usecase.js";
import { MarkNotificationReadUseCase } from "../../usecases/notifications/mark-notification-read.usecase.js";
import { UnauthorizedError, ValidationError } from "../../utils/errors.js";
import { notificationTarget } from "../../services/notifications/notification-target.js";
import { emitDataChange } from "../../realtime/data-changes.js";
import { listNotificationsQuerySchema } from "../../validators/notifications/notification.validator.js";
import type { Notification } from "../../types/notifications/notification.types.js";

export class NotificationController {
  constructor(
    private readonly listNotifications = new ListNotificationsUseCase(),
    private readonly markRead = new MarkNotificationReadUseCase(),
    private readonly markAllRead = new MarkAllNotificationsReadUseCase(),
  ) {}

  list = async (req: Request, res: Response, next: NextFunction) => {
    try {
      if (!req.user?.uid) throw new UnauthorizedError();

      const parsed = listNotificationsQuerySchema.safeParse(req.query);
      if (!parsed.success) {
        throw new ValidationError(
          parsed.error.issues
            .map((issue) => `${issue.path.join(".") || "request"}: ${issue.message}`)
            .join("; "),
        );
      }
      const { limit, cursor } = parsed.data;
      const toResponse = (row: Notification) => {
        const target = notificationTarget(row.event_key, row.type);
        return { ...row, eventType: target.type, messageId: target.messageId };
      };

      const page = await this.listNotifications.executePage(req.user.uid, {
        limit: limit ?? 20,
        cursor,
      });
      res.json({
        success: true,
        data: page.items.map(toResponse),
        next_cursor: page.nextCursor,
        pagination: { limit: limit ?? 20, nextCursor: page.nextCursor },
      });
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
      emitDataChange({ kind: "inbox" }, [req.user.uid]);
      res.json({ success: true, data: notification });
    } catch (error) {
      next(error);
    }
  };

  markAllAsRead = async (req: Request, res: Response, next: NextFunction) => {
    try {
      if (!req.user?.uid) throw new UnauthorizedError();
      const result = await this.markAllRead.execute(req.user.uid);
      emitDataChange({ kind: "inbox" }, [req.user.uid]);
      res.json({ success: true, data: result });
    } catch (error) {
      next(error);
    }
  };
}
