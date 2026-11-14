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
): () => Promise<void> {
  let running = false;
  let inFlight: Promise<void> = Promise.resolve();

  const tick = async () => {
    if (running) return;
    running = true;
    try {
      await enqueueDueNotificationReminders().catch((error) =>
        console.error("[notifications] reminders failed", error),
      );
      const count = await dispatcher.processBatch();
      if (count > 0) {
        console.log(`[notifications] processed ${count} event(s)`);
      }
    } catch (error) {
      console.error("[notifications] worker tick failed", error);
    } finally {
      running = false;
    }
  };

  const trigger = () => {
    if (!running) inFlight = tick();
  };
  trigger();
  const timer = setInterval(trigger, config.worker.intervalMs);
  timer.unref();

  return async () => {
    clearInterval(timer);
    await inFlight;
  };
}
