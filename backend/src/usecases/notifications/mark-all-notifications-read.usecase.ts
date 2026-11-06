import type { INotificationRepository } from "../../repositories/notifications/i-notification.repository.js";
import { NotificationRepository } from "../../repositories/notifications/notification.repository.js";

export type MarkAllNotificationsReadResult = {
  count: number;
};

export class MarkAllNotificationsReadUseCase {
  constructor(
    private readonly notifications: INotificationRepository = new NotificationRepository(),
  ) {}

  /** Marks every unread notification for the caller as read. */
  async execute(callerUid: string): Promise<MarkAllNotificationsReadResult> {
    return this.notifications.markAllRead(callerUid);
  }
}
