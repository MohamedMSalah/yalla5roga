import { prisma } from "../config/database.js";

const INTERVAL_MS = 60 * 1000;

/**
 * Marks upcoming outings as past once they have ended. An outing without an
 * explicit ends_at is treated as lasting six hours after scheduled_at.
 * `WHERE status = 'upcoming'` keeps the statement idempotent, and the raw
 * UPDATE sets updated_at itself because @updatedAt does not run for raw SQL.
 * The partial index idx_outings_upcoming_due serves this query.
 */
export async function completeFinishedOutings(): Promise<string[]> {
  const finished = await prisma.$queryRaw<{ id: string }[]>`
    UPDATE outings
    SET status = 'past', updated_at = now()
    WHERE status = 'upcoming'
      AND COALESCE(ends_at, scheduled_at + interval '6 hours') <= now()
    RETURNING id
  `;
  return finished.map((row) => row.id);
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
