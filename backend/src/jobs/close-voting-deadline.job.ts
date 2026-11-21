import { scheduleJob } from "../monitoring/jobs.js";
import { errorCode, logger } from "../monitoring/logger.js";
import { increment } from "../monitoring/metrics.js";
import { prisma } from "../config/database.js";
import {
  closeVotingByDeadline,
  emitResolutionNotifications,
} from "../services/outings/vote-resolution.js";

const INTERVAL_MS = 30 * 1000;

/** Closes voting for outings whose deadline has passed. */
export async function closeDueVotingDeadlines(): Promise<string[]> {
  const due = await prisma.$queryRaw<{ id: string }[]>`
    SELECT o.id FROM outings o
    WHERE o.status = 'voting' AND o.vote_closed_at IS NULL AND o.vote_ends_at <= now()
      AND EXISTS (
        SELECT 1 FROM outing_voting_round_options candidate
        WHERE candidate.outing_id = o.id AND candidate.round_number = o.current_voting_round
        OFFSET 1
      )
    ORDER BY o.vote_ends_at, o.id
    LIMIT 50
  `;

  const closed: string[] = [];
  for (const row of due) {
    try {
      const result = await closeVotingByDeadline(row.id);
      if (result) {
        closed.push(row.id);
        await emitResolutionNotifications(result);
      }
    } catch (error) {
      increment("job_item_failures_total", { job: "close_voting" });
      logger.debug({ errorCode: errorCode(error) }, "Voting deadline item failed");
    }
  }
  return closed;
}

export function startVotingDeadlineJob() {
  return scheduleJob("close_voting", INTERVAL_MS, async () => { await closeDueVotingDeadlines(); });
}
