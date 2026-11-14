import { NotificationRepository } from "../../repositories/notifications/notification.repository.js";
import {
  ForbiddenError,
  NotFoundError,
  ValidationError,
} from "../../utils/errors.js";
import { notificationPreferencesSchema } from "../../services/notifications/notification-preferences.js";
import { notificationTarget } from "../../services/notifications/notification-target.js";
import { resolvePush } from "../../services/notifications/resolve-push.js";

export class NotificationStateUseCase {
  constructor(private readonly notifications = new NotificationRepository()) {}
  summary(uid: string) {
    return this.notifications.summary(uid);
  }
  async preferences(uid: string) {
    return (await this.summary(uid)).preferences;
  }
  updatePreferences(uid: string, body: unknown) {
    const parsed = notificationPreferencesSchema
      .partial()
      .strict()
      .safeParse(body);
    if (!parsed.success)
      throw new ValidationError("Invalid notification preferences");
    return this.notifications.updatePreferences(uid, parsed.data);
  }
  async systemPayload(uid: string, id: string) {
    const row = await this.notifications.findById(id);
    if (!row) throw new NotFoundError("Notification");
    if (row.user_id !== uid) throw new ForbiddenError("Not your notification");
    const target = notificationTarget(row.event_key, row.type);
    const payload = await resolvePush(
      uid,
      {
        ...target,
        notificationId: id,
        eventId: id,
        notificationType: target.type,
        actionType: "open",
        createdAt: row.created_at.toISOString(),
        title: "Yalla 5roga",
        body: row.body,
        recipientUserId: uid,
        groupId: row.group_id,
        outingId: row.outing_id,
        ...(row.data as Record<string, string>),
      },
      row.event_key,
    );
    return { available: payload !== null, payload };
  }
}
