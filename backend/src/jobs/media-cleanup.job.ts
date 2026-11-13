import { getMediaConfig } from "../config/media.js";
import { MediaService } from "../services/media/media.service.js";

/**
 * Deletes orphaned media:
 * - `pending` intents whose presigned upload window elapsed without a confirm
 * - `failed` rows where the object never landed in storage
 *
 * Removes the storage object first (best effort) and then the metadata row.
 */
export async function cleanupExpiredMedia(
  service: MediaService = new MediaService(),
): Promise<{ removed: number }> {
  return service.cleanupExpired(100);
}

export function startMediaCleanupJob(): () => void {
  const { cleanupIntervalMs } = getMediaConfig();
  const service = new MediaService();
  let running = false;

  const tick = async () => {
    if (running) return;
    running = true;
    try {
      const { removed } = await cleanupExpiredMedia(service);
      if (removed > 0) {
        console.log(`[media] cleaned up ${removed} orphaned asset(s)`);
      }
    } catch (error) {
      console.error("[media] cleanup job failed", error);
    } finally {
      running = false;
    }
  };

  void tick();
  const timer = setInterval(() => void tick(), cleanupIntervalMs);
  timer.unref();
  return () => clearInterval(timer);
}
