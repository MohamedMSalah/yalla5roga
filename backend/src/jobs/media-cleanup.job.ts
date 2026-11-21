import { scheduleJob } from "../monitoring/jobs.js";
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

export function startMediaCleanupJob() {
  const { cleanupIntervalMs } = getMediaConfig();
  const service = new MediaService();
  return scheduleJob("media_cleanup", cleanupIntervalMs, async () => { await cleanupExpiredMedia(service); });
}
