import type { INotificationRepository } from "../../repositories/notifications/i-notification.repository.js";
import { NotificationRepository } from "../../repositories/notifications/notification.repository.js";
import type { Notification } from "../../types/notifications/notification.types.js";
import { ForbiddenError, NotFoundError } from "../../utils/errors.js";

export class MarkNotificationReadUseCase {
  constructor(
    private readonly notifications: INotificationRepository = new NotificationRepository(),
  ) {}

  async execute(id: string, callerUid: string): Promise<Notification> {
    const existing = await this.notifications.findById(id);
    if (!existing) throw new NotFoundError("Notification");
    if (existing.user_id !== callerUid) {
      throw new ForbiddenError(
        "Only the notification recipient can mark it as read",
      );
    }
    return this.notifications.update(id, { is_read: true });
  }
}
