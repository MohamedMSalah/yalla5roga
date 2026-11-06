import { prisma } from "../config/database.js";
import {
  closeVotingByDeadline,
  emitResolutionNotifications,
} from "../services/outings/vote-resolution.js";

const INTERVAL_MS = 30 * 1000;

/** Closes voting for outings whose deadline has passed. */
export async function closeDueVotingDeadlines(): Promise<string[]> {
  const due = await prisma.outings.findMany({
    where: {
      status: "voting",
      vote_closed_at: null,
      vote_ends_at: { lte: new Date() },
    },
    select: { id: true },
    take: 50,
  });

  const closed: string[] = [];
  for (const row of due) {
    const result = await closeVotingByDeadline(row.id);
    if (result) {
      closed.push(row.id);
      await emitResolutionNotifications(result);
    }
  }
  return closed;
}

export function startVotingDeadlineJob(): () => void {
  let running = false;

  const tick = async () => {
    if (running) return;
    running = true;
    try {
      const ids = await closeDueVotingDeadlines();
      if (ids.length > 0) {
        console.log(`[outings] closed voting for ${ids.length} outing(s) by deadline`);
      }
    } catch (error) {
      console.error("[outings] voting deadline job failed", error);
    } finally {
      running = false;
    }
  };

  void tick();
  const timer = setInterval(() => void tick(), INTERVAL_MS);
  timer.unref();
  return () => clearInterval(timer);
}
