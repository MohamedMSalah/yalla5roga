import type { Prisma } from "@prisma/client";
import { meetupOptimizationPolicyVersion, type MeetupCalculation } from "../../types/meetups/meetup-result.js";

export class MeetupInvalidationService {
  isCurrent(calculation: MeetupCalculation, session: {
    id: string; status: string; input_version: number; expires_at: Date;
  }, fingerprint: string | null, now = new Date()) {
    const completed = ["READY", "PARTIAL", "NO_MATCHING_VENUES"].includes(calculation.calculation_status);
    return calculation.meetup_session_id === session.id && session.status === "ACTIVE" &&
      session.expires_at > now && calculation.calculation_status !== "STALE" &&
      calculation.input_version === session.input_version && calculation.input_fingerprint === fingerprint &&
      calculation.optimization_policy_version === meetupOptimizationPolicyVersion &&
      calculation.expires_at !== null && calculation.expires_at > now &&
      (!completed || (calculation.calculated_at !== null && calculation.included_participant_count > 0));
  }

  async invalidate(tx: Prisma.TransactionClient, calculation: MeetupCalculation) {
    if (calculation.calculation_status === "STALE") return;
    // The calculation trigger enqueues the versioned change in this transaction.
    await tx.meetup_calculations.update({ where: { id: calculation.id }, data: { calculation_status: "STALE" } });
  }
}
