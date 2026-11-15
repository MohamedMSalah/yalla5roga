import { randomInt } from "node:crypto";
import type { Prisma, vote_close_reason } from "@prisma/client";
import { prisma } from "../../config/database.js";
import type { Outing } from "../../types/outings/outing.types.js";
import { ConflictError, ForbiddenError, NotFoundError, ValidationError,
} from "../../utils/errors.js";
import { publishOutingChange } from "../../realtime/data-changes.js";
import { persistOutingTransition } from "../notifications/outing-events.js";
import { notifyOutingParticipants } from "../notifications/outing-notifier.js";
import { listEligibleVoterIds } from "./outing-participants.js";

export type VoteResolutionResult = {
  outing: Outing;
  outcome: "confirmed" | "tie" | "cancelled" | "still_open";
  winningOptionId?: string;
  tiedOptionIds?: string[];
  voting_state?: "confirmed";
  resolution_method?: string | null;
  confirmed_location?: Prisma.outing_vote_optionsGetPayload<object> | null;
};

type Tx = Prisma.TransactionClient;

function tallies(votes: { option_id: string }[]): Map<string, number> {
  const counts = new Map<string, number>();
  for (const vote of votes) {
    counts.set(vote.option_id, (counts.get(vote.option_id) ?? 0) + 1);
  }
  return counts;
}

async function applyWinner(
  tx: Tx,
  outingId: string,
  optionId: string,
  closeReason: vote_close_reason,
): Promise<Outing> {
  const option = await tx.outing_vote_options.findFirst({
    where: { id: optionId, outing_id: outingId },
  });
  if (!option) throw new NotFoundError("Vote option");

  const before = await tx.outings.findUniqueOrThrow({
    where: { id: outingId },
  });
  const candidate = await tx.outing_voting_round_options.findUnique({ where: { outing_id_round_number_option_id: { outing_id: outingId, round_number: before.current_voting_round, option_id: optionId } } });
  if (!candidate) throw new ConflictError("Location is not eligible in the current round");
  if (closeReason === "owner_confirmed") {
    const voters = await listEligibleVoterIds(before, tx);
    const votes = await tx.outing_votes.findMany({ where: { outing_id: outingId, round_number: before.current_voting_round, user_id: { in: voters } } });
    const counts = tallies(votes);
    const options = await tx.outing_voting_round_options.findMany({ where: { outing_id: outingId, round_number: before.current_voting_round } });
    for (const option of options) await tx.outing_voting_round_options.update({ where: { outing_id_round_number_option_id: { outing_id: outingId, round_number: before.current_voting_round, option_id: option.option_id } }, data: { vote_count: counts.get(option.option_id) ?? 0 } });
  }
  const updated = await tx.outings.update({
    where: { id: outingId },
    data: {
      status: "confirmed",
      resolution_method: closeReason === "tie_break" ? "random" : closeReason === "owner_confirmed" ? "creator" : "votes",
      resolved_at: new Date(),
      vote_closed_at: new Date(),
      vote_close_reason: closeReason,
      winning_option_id: option.id,
      location_place_id: option.place_id,
      location_name: option.label,
      location_area: option.area || null,
      location_latitude: option.latitude,
      location_longitude: option.longitude,
    },
  });
  await tx.outing_voting_rounds.update({ where: { outing_id_round_number: { outing_id: outingId, round_number: before.current_voting_round } }, data: { status: "confirmed", ends_at: updated.vote_ends_at } });
  await persistOutingTransition(tx, before, updated);
  return updated;
}

async function markVotingClosedPendingTie(
  tx: Tx,
  outingId: string,
  closeReason: vote_close_reason,
): Promise<Outing> {
  const before = await tx.outings.findUniqueOrThrow({
    where: { id: outingId },
  });
  const updated = await tx.outings.update({
    where: { id: outingId },
    data: {
      // Stay in voting but record closure metadata so votes are rejected.
      // Status remains voting until owner tie-breaks; vote_closed_at locks ballots.
      vote_closed_at: new Date(),
      vote_close_reason: closeReason,
    },
  });
  await tx.outing_voting_rounds.update({ where: { outing_id_round_number: { outing_id: outingId, round_number: before.current_voting_round } }, data: { status: "tie_pending", ends_at: updated.vote_ends_at } });
  const data = { navigationSection: "voting", votingState: "tie_pending", roundNumber: String(before.current_voting_round) };
  await notifyOutingParticipants({ outing: updated, type: "vote", eventType: "voting_closed",
    body: closeReason === "zero_votes" ? "No place received votes. Waiting for the outing creator to decide." : "There's a tie between the proposed places. Waiting for the outing creator to decide.",
    excludeUserId: before.created_by, eventKey: `voting_tie:${outingId}:${before.current_voting_round}`, data }, tx);
  await notifyOutingParticipants({ outing: updated, type: "vote", eventType: "voting_closed", userIds: [before.created_by], actionRequired: true,
    body: "Your location vote needs a decision. Roll the dice or start a revote.", eventKey: `voting_tie_creator:${outingId}:${before.current_voting_round}`, data }, tx);
  await persistOutingTransition(tx, before, updated);
  return updated;
}

/**
 * Freeze current-round results at the backend deadline.
 * Must run inside a transaction that already locked the outing row.
 */
export async function resolveClosedVoting(
  tx: Tx,
  outing: Outing,
  closeReason: vote_close_reason,
): Promise<VoteResolutionResult> {
  if (outing.status === "confirmed") {
    return {
      outing,
      outcome: "confirmed",
      winningOptionId: outing.winning_option_id ?? undefined,
    };
  }
  if (outing.status === "cancelled") {
    return { outing, outcome: "cancelled" };
  }
  if (outing.vote_closed_at && outing.winning_option_id) {
    return {
      outing,
      outcome: "confirmed",
      winningOptionId: outing.winning_option_id,
    };
  }
  if (outing.status !== "voting") return { outing, outcome: "still_open" };
  const round = outing.current_voting_round;
  const candidates = await tx.outing_voting_round_options.findMany({ where: { outing_id: outing.id, round_number: round } });
  if (outing.vote_closed_at) return { outing, outcome: "tie", tiedOptionIds: candidates.filter(c => c.is_tied).map(c => c.option_id) };
  const eligible = await listEligibleVoterIds(outing, tx);
  const votes = await tx.outing_votes.findMany({ where: { outing_id: outing.id, round_number: round, user_id: { in: eligible } }, select: { option_id: true } });
  const counts = tallies(votes);
  const max = Math.max(0, ...candidates.map(c => counts.get(c.option_id) ?? 0));
  const leaders = candidates.filter(c => (counts.get(c.option_id) ?? 0) === max).map(c => c.option_id);
  for (const candidate of candidates) await tx.outing_voting_round_options.update({
    where: { outing_id_round_number_option_id: { outing_id: outing.id, round_number: round, option_id: candidate.option_id } },
    data: { vote_count: counts.get(candidate.option_id) ?? 0, is_tied: leaders.includes(candidate.option_id) },
  });
  // Single proposed venue retains explicit creator confirmation.
  if (candidates.length < 2) return { outing, outcome: "still_open" };
  if (leaders.length === 1 && max > 0) {
    const confirmed = await applyWinner(tx, outing.id, leaders[0]!, "unique_winner");
    return { outing: confirmed, outcome: "confirmed", winningOptionId: leaders[0] };
  }
  const tied = await markVotingClosedPendingTie(tx, outing.id, max === 0 ? "zero_votes" : closeReason);
  return { outing: tied, outcome: "tie", tiedOptionIds: leaders };
}

export async function tryCloseIfAllVoted(outingId: string): Promise<VoteResolutionResult | null> {
  return closeVotingByDeadline(outingId);
}

export async function closeVotingByDeadline(
  outingId: string,
): Promise<VoteResolutionResult | null> {
  return prisma.$transaction(async (tx) => {
    const locked = await tx.$queryRaw<Outing[]>`
      SELECT * FROM outings WHERE id = ${outingId}::uuid FOR UPDATE
    `;
    const outing = locked[0];
    if (!outing) throw new NotFoundError("Outing");
    if (outing.status !== "voting" || outing.vote_closed_at) {
      return null;
    }
    if (!outing.vote_ends_at || outing.vote_ends_at > new Date()) {
      return null;
    }
    if (await tx.outing_voting_round_options.count({ where: { outing_id: outingId, round_number: outing.current_voting_round } }) < 2) return null;
    return resolveClosedVoting(tx, outing, "deadline");
  });
}

/**
 * Owner-only random selection among tied leaders. Backend is the sole RNG.
 * Concurrent / repeat calls are idempotent once confirmed.
 */
export async function breakTieRandomly(
  outingId: string,
  callerUid: string,
  expectedRound?: number,
): Promise<VoteResolutionResult> {
  const result = await prisma.$transaction(async (tx) => {
    const locked = await tx.$queryRaw<Outing[]>`
      SELECT * FROM outings WHERE id = ${outingId}::uuid FOR UPDATE
    `;
    const outing = locked[0];
    if (!outing) throw new NotFoundError("Outing");
    if (outing.created_by !== callerUid) {
      throw new ForbiddenError("Only the outing owner can break a tie");
    }
    if ((expectedRound ?? 1) !== outing.current_voting_round) throw new ConflictError("Voting round changed");
    if (outing.status === "confirmed" && outing.winning_option_id && outing.resolution_method === "random") {
      return {
        outing,
        outcome: "confirmed" as const,
        winningOptionId: outing.winning_option_id,
        voting_state: "confirmed" as const,
        resolution_method: outing.resolution_method,
        confirmed_location: await tx.outing_vote_options.findUnique({ where: { id: outing.winning_option_id } }),
      };
    }
    if (outing.status === "cancelled") {
      throw new ConflictError("Outing is cancelled");
    }
    if (outing.status !== "voting") {
      throw new ConflictError("Outing is not awaiting a tie-break");
    }
    if (!outing.vote_closed_at) {
      throw new ConflictError("Voting is still open");
    }

    const endsAt = outing.ends_at ?? (outing.scheduled_at ? new Date(outing.scheduled_at.getTime() + 6 * 3600000) : null);
    if (endsAt && endsAt.getTime() <= Date.now()) throw new ConflictError("Outing has completed");
    const currentRound = await tx.outing_voting_rounds.findUniqueOrThrow({ where: { outing_id_round_number: { outing_id: outingId, round_number: outing.current_voting_round } } });
    if (currentRound.status !== "tie_pending") throw new ConflictError("Round is not awaiting tie resolution");
    const candidates = await tx.outing_voting_round_options.findMany({ where: { outing_id: outingId, round_number: outing.current_voting_round, is_tied: true } });
    const leaders = candidates.map(c => c.option_id);
    if (leaders.length < 2) throw new ConflictError("No tie to break");

    // Deterministic-safe random index from crypto RNG.
    const index = randomInt(leaders.length);
    const winnerId = leaders[index]!;
    const confirmed = await applyWinner(tx, outingId, winnerId, "tie_break");
    return {
      outing: confirmed,
      outcome: "confirmed" as const,
      winningOptionId: winnerId,
      voting_state: "confirmed" as const,
      resolution_method: confirmed.resolution_method,
      confirmed_location: await tx.outing_vote_options.findUnique({ where: { id: winnerId } }),
      tiedOptionIds: leaders,
    };
  });

  return result;
}

export async function confirmProposedVenue(
  outingId: string,
  callerUid: string,
  optionId: string,
): Promise<VoteResolutionResult> {
  const result = await prisma.$transaction(async (tx) => {
    const [outing] = await tx.$queryRaw<Outing[]>`
      SELECT * FROM outings WHERE id = ${outingId}::uuid FOR UPDATE
    `;
    if (!outing) throw new NotFoundError("Outing");
    if (outing.created_by !== callerUid) {
      throw new ForbiddenError("Only the outing owner can confirm the venue");
    }
    if (outing.status === "confirmed" && outing.winning_option_id === optionId) {
      return { outing, outcome: "confirmed" as const, winningOptionId: optionId,
      };
    }
    if (outing.status !== "voting") {
      throw new ConflictError("This outing is no longer awaiting a venue");
    }
    if (outing.current_voting_round > 1) throw new ConflictError("Revote must resolve through the round result");
    if (outing.vote_closed_at && await tx.outing_voting_round_options.count({ where: { outing_id: outingId, round_number: outing.current_voting_round } }) > 1) throw new ConflictError("Resolve the pending tie instead");
    const confirmed = await applyWinner(tx, outingId, optionId, "owner_confirmed",
    );
    return { outing: confirmed, outcome: "confirmed" as const, winningOptionId: optionId,
    };
  });
  await emitResolutionNotifications(result).catch((error: unknown) => {
    console.error("[voting] venue confirmation notification failed", error);
  });
  return result;
}

export async function emitResolutionNotifications(
  result: VoteResolutionResult,
): Promise<void> {
  const { outing } = result;
  await publishOutingChange(outing.id, "outing", [], result.outcome === "tie" ? "outing:voting_tie_detected" : result.outcome === "confirmed" ? "outing:location_confirmed" : "outing:voting_round_updated").catch(() => {});
}

export function assertVotingOpen(outing: Outing): void {
  if (outing.status !== "voting") {
    throw new ConflictError("Voting is not open for this outing");
  }
  if (outing.vote_closed_at) {
    throw new ConflictError("Voting is locked");
  }
}

export function assertCanAddVoteOption(outing: Outing): void {
  if (outing.current_voting_round > 1) throw new ConflictError("Revote candidates are fixed");
  if (outing.status === "cancelled" || outing.status === "past") {
    throw new ConflictError("Cannot add candidates to a closed outing");
  }
  if (outing.vote_closed_at || outing.status === "confirmed") {
    throw new ConflictError("Voting is locked");
  }
}

export function assertValidStatusTransition(
  from: Outing["status"],
  to: Outing["status"],
): void {
  if (from === to) return;
  const allowed: Record<Outing["status"], Outing["status"][]> = {
    draft: ["voting", "cancelled"],
    voting: ["confirmed", "cancelled"],
    confirmed: ["cancelled", "past"],
    cancelled: [],
    past: [],
  };
  if (!allowed[from].includes(to)) {
    throw new ValidationError(`Invalid status transition ${from} → ${to}`);
  }
  if (from === "confirmed" && to === "voting") {
    throw new ValidationError("Confirmed outings cannot reopen voting");
  }
}


/** Serialized with ballots, closure, cancellation and random resolution by the outing lock. */
export async function startRevote(outingId: string, uid: string, deadline: Date, expectedRound?: number) {
  const outing = await prisma.$transaction(async tx => {
    const [before] = await tx.$queryRaw<Outing[]>`SELECT * FROM outings WHERE id = ${outingId}::uuid FOR UPDATE`;
    if (!before) throw new NotFoundError("Outing");
    if (before.created_by !== uid) throw new ForbiddenError("Only the outing creator can start a revote");
    if ((expectedRound ?? 1) !== before.current_voting_round) throw new ConflictError("Voting round changed");
    if (before.status !== "voting" || !before.vote_closed_at) throw new ConflictError("Voting is not awaiting tie resolution");
    if (!Number.isFinite(deadline.getTime()) || deadline.getTime() <= Date.now() || deadline.getTime() > Date.now() + 168 * 3600000 || (before.scheduled_at && deadline >= before.scheduled_at)) throw new ValidationError("Choose a future deadline within seven days and before the outing starts");
    const previous = await tx.outing_voting_rounds.findUniqueOrThrow({ where: { outing_id_round_number: { outing_id: outingId, round_number: before.current_voting_round } }, include: { options: { where: { is_tied: true } } } });
    if (previous.status !== "tie_pending" || previous.options.length < 2) throw new ConflictError("No tied round to restart");
    await tx.outing_voting_rounds.update({ where: { id: previous.id }, data: { status: "closed" } });
    const next = before.current_voting_round + 1;
    await tx.outing_voting_rounds.create({ data: { outing_id: outingId, round_number: next, ends_at: deadline,
      options: { create: previous.options.map(o => ({ option_id: o.option_id })) } } });
    const updated = await tx.outings.update({ where: { id: outingId }, data: { current_voting_round: next, vote_ends_at: deadline, vote_closed_at: null, vote_close_reason: null } });
    await notifyOutingParticipants({ outing: updated, type: "vote", eventType: "voting_started", body: "A new voting round has started. Vote for your preferred place!", eventKey: `revote:${outingId}:${next}`, data: { navigationSection: "voting", roundNumber: String(next) } }, tx);
    return updated;
  });
  await publishOutingChange(outingId, "outing", [], "outing:voting_revote_started").catch(() => {});
  return outing;
}
