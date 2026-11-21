import { scheduleJob } from "../monitoring/jobs.js";
import { getNotificationConfig } from "../config/notifications.js";
import { NotificationDispatcher } from "../services/notifications/dispatch-notification.js";
import { enqueueDueNotificationReminders } from "./notification-reminders.job.js";

/**
 * Background consumer for the notification outbox. Mirrors the architecture
 * diagram's Notification Worker: claim → deliver (WhatsApp) → log → retry.
 */
export function startNotificationWorker(
  dispatcher = new NotificationDispatcher(),
  config = getNotificationConfig(),
) {
  return scheduleJob("notification_worker", config.worker.intervalMs, async () => {
    // A reminder failure must not stop already queued notifications from delivering.
    const reminder = await enqueueDueNotificationReminders().then(() => ({ ok: true } as const),
      (error: unknown) => ({ ok: false, error } as const));
    await dispatcher.processBatch();
    if (!reminder.ok) throw reminder.error;
  });
}
