import type { INotificationRepository } from "../../repositories/notifications/i-notification.repository.js";
import { NotificationRepository } from "../../repositories/notifications/notification.repository.js";
import type { Notification } from "../../types/notifications/notification.types.js";

export class ListNotificationsUseCase {
  constructor(
    private readonly notifications: INotificationRepository = new NotificationRepository(),
  ) {}

  execute(userId: string): Promise<Notification[]> {
    return this.notifications.findByUserId(userId);
  }
}
