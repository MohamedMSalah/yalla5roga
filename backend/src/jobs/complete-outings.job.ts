import { prisma } from "../config/database.js";
import { publishOutingChange } from "../realtime/data-changes.js";

const INTERVAL_MS = 60 * 1000;

/**
 * Marks confirmed outings as past once they have ended. An outing without an
 * explicit ends_at is treated as lasting six hours after scheduled_at.
 */
export async function completeFinishedOutings(): Promise<string[]> {
  const finished = await prisma.$queryRaw<{ id: string }[]>`
    UPDATE outings
    SET status = 'past', updated_at = now()
    WHERE status = 'confirmed'
      AND COALESCE(ends_at, scheduled_at + interval '6 hours') <= now()
    RETURNING id
  `;
  const ids = finished.map((row) => row.id);
  await Promise.all(ids.map((id) => publishOutingChange(id)));
  return ids;
}

/** Runs the completion step once a minute. Returns a stop function. */
export function startOutingCompletionJob(): () => void {
  let running = false;

  const tick = async () => {
    if (running) return;
    running = true;
    try {
      const ids = await completeFinishedOutings();
      if (ids.length > 0) {
        console.log(`[outings] marked ${ids.length} outing(s) as past`);
      }
    } catch (error) {
      console.error("[outings] completion job failed", error);
    } finally {
      running = false;
    }
  };

  void tick();
  const timer = setInterval(() => void tick(), INTERVAL_MS);
  timer.unref();

  return () => clearInterval(timer);
}
