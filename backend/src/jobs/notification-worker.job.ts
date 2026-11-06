import { getNotificationConfig } from "../config/notifications.js";
import { NotificationDispatcher } from "../services/notifications/dispatch-notification.js";

/**
 * Background consumer for the notification outbox. Mirrors the architecture
 * diagram's Notification Worker: claim → deliver (WhatsApp) → log → retry.
 */
export function startNotificationWorker(
  dispatcher = new NotificationDispatcher(),
  config = getNotificationConfig(),
): () => void {
  let running = false;

  const tick = async () => {
    if (running) return;
    running = true;
    try {
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

  void tick();
  const timer = setInterval(() => void tick(), config.worker.intervalMs);
  timer.unref();

  return () => clearInterval(timer);
}
