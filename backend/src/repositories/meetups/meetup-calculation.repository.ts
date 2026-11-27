import type { Prisma } from "@prisma/client";
import { meetupOptimizationPolicyVersion } from "../../types/meetups/meetup-result.js";
import type { MeetupReadinessSummary } from "../../types/meetups/meetup-session.js";

export class MeetupCalculationRepository {
  latest(tx: Prisma.TransactionClient, meetupSessionId: string) {
    return tx.meetup_calculations.findFirst({
      where: { meetup_session_id: meetupSessionId },
      orderBy: [{ input_version: "desc" }, { attempt: "desc" }],
    });
  }

  get(tx: Prisma.TransactionClient, meetupSessionId: string, id: string) {
    return tx.meetup_calculations.findFirst({ where: { id, meetup_session_id: meetupSessionId } });
  }

  create(tx: Prisma.TransactionClient, sessionId: string, inputVersion: number, fingerprint: string,
    attempt: number, readiness: MeetupReadinessSummary, expiresAt: Date) {
    return tx.meetup_calculations.create({ data: {
      meetup_session_id: sessionId, input_version: inputVersion, input_fingerprint: fingerprint, attempt,
      calculation_status: readiness.usable === 0 ? "INSUFFICIENT_DATA" : "ROUTING_UNAVAILABLE",
      optimization_policy_version: meetupOptimizationPolicyVersion,
      intended_participant_count: readiness.intended, included_participant_count: readiness.usable,
      unavailable_participant_count: readiness.requiring_setup, is_partial: readiness.status === "PARTIAL",
      expires_at: expiresAt,
    } });
  }
}
