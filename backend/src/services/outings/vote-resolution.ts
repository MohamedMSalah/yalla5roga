import { createHash, randomInt } from "node:crypto";
import type { Prisma, vote_close_reason } from "@prisma/client";
import { prisma } from "../../config/database.js";
import type { Outing } from "../../types/outings/outing.types.js";
import { ConflictError, ForbiddenError, NotFoundError, ValidationError } from "../../utils/errors.js";
import { publishOutingChange } from "../../realtime/data-changes.js";
import { notifyOutingParticipants } from "../notifications/outing-notifier.js";
import { listEligibleVoterIds } from "./outing-participants.js";

export type VoteResolutionResult = {
  outing: Outing;
  outcome: "confirmed" | "tie" | "cancelled" | "still_open";
  winningOptionId?: string;
  tiedOptionIds?: string[];
};

type Tx = Prisma.TransactionClient;

function tallies(votes: { option_id: string }[]): Map<string, number> {
  const counts = new Map<string, number>();
  for (const vote of votes) {
    counts.set(vote.option_id, (counts.get(vote.option_id) ?? 0) + 1);
  }
  return counts;
}

function topOptions(counts: Map<string, number>): {
  max: number;
  leaders: string[];
} {
  let max = 0;
  const leaders: string[] = [];
  for (const [optionId, count] of counts) {
    if (count > max) {
      max = count;
      leaders.length = 0;
      leaders.push(optionId);
    } else if (count === max && count > 0) {
      leaders.push(optionId);
    }
  }
  return { max, leaders };
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

  return tx.outings.update({
    where: { id: outingId },
    data: {
      status: "confirmed",
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
}

async function applyCancelZeroVotes(
  tx: Tx,
  outingId: string,
  closeReason: vote_close_reason,
): Promise<Outing> {
  return tx.outings.update({
    where: { id: outingId },
    data: {
      status: "cancelled",
      vote_closed_at: new Date(),
      vote_close_reason: closeReason,
      winning_option_id: null,
    },
  });
}

async function markVotingClosedPendingTie(
  tx: Tx,
  outingId: string,
  closeReason: vote_close_reason,
): Promise<Outing> {
  return tx.outings.update({
    where: { id: outingId },
    data: {
      // Stay in voting but record closure metadata so votes are rejected.
      // Status remains voting until owner tie-breaks; vote_closed_at locks ballots.
      vote_closed_at: new Date(),
      vote_close_reason: closeReason,
    },
  });
}

/**
 * Evaluate tallies after voting participation is complete or the deadline hit.
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
  if (outing.vote_closed_at && !outing.winning_option_id && outing.status === "voting") {
    const votes = await tx.outing_votes.findMany({
      where: { outing_id: outing.id },
      select: { option_id: true },
    });
    const { leaders } = topOptions(tallies(votes));
    return {
      outing,
      outcome: "tie",
      tiedOptionIds: leaders,
    };
  }

  const votes = await tx.outing_votes.findMany({
    where: { outing_id: outing.id },
    select: { option_id: true },
  });

  if (votes.length === 0) {
    const cancelled = await applyCancelZeroVotes(tx, outing.id, "zero_votes");
    return { outing: cancelled, outcome: "cancelled" };
  }

  const { leaders } = topOptions(tallies(votes));
  if (leaders.length === 1) {
    const confirmed = await applyWinner(
      tx,
      outing.id,
      leaders[0]!,
      closeReason === "deadline" || closeReason === "all_voted"
        ? "unique_winner"
        : closeReason,
    );
    return {
      outing: confirmed,
      outcome: "confirmed",
      winningOptionId: leaders[0],
    };
  }

  const tied = await markVotingClosedPendingTie(tx, outing.id, closeReason);
  return { outing: tied, outcome: "tie", tiedOptionIds: leaders };
}

export async function tryCloseIfAllVoted(
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

    const eligible = await listEligibleVoterIds(outing, tx);
    if (eligible.length === 0) return null;

    const votes = await tx.outing_votes.findMany({
      where: { outing_id: outingId },
      select: { user_id: true },
    });
    const voters = new Set(votes.map((v) => v.user_id));
    const allVoted = eligible.every((id) => voters.has(id));
    if (!allVoted) return null;

    return resolveClosedVoting(tx, outing, "all_voted");
  });
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
    if (outing.status === "confirmed" && outing.winning_option_id) {
      return {
        outing,
        outcome: "confirmed" as const,
        winningOptionId: outing.winning_option_id,
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

    const votes = await tx.outing_votes.findMany({
      where: { outing_id: outingId },
      select: { option_id: true },
    });
    if (votes.length === 0) {
      throw new ConflictError("No votes to break");
    }
    const { leaders } = topOptions(tallies(votes));
    if (leaders.length < 2) {
      throw new ConflictError("No tie to break");
    }

    // Deterministic-safe random index from crypto RNG.
    const index = randomInt(leaders.length);
    const winnerId = leaders[index]!;
    const confirmed = await applyWinner(tx, outingId, winnerId, "tie_break");
    return {
      outing: confirmed,
      outcome: "confirmed" as const,
      winningOptionId: winnerId,
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
      return { outing, outcome: "confirmed" as const, winningOptionId: optionId };
    }
    if (outing.status !== "voting") {
      throw new ConflictError("This outing is no longer awaiting a venue");
    }
    const confirmed = await applyWinner(tx, outingId, optionId, "owner_confirmed");
    return { outing: confirmed, outcome: "confirmed" as const, winningOptionId: optionId };
  });
  await emitResolutionNotifications(result).catch((error: unknown) => {
    console.error("[voting] venue confirmation notification failed", error);
  });
  return result;
}

export async function emitResolutionNotifications(
  result: VoteResolutionResult,
): Promise<void> {
  const { outing, outcome } = result;
  await publishOutingChange(outing.id);
  if (outcome === "confirmed" && result.winningOptionId) {
    const eventType =
      outing.vote_close_reason === "tie_break"
        ? "tie_break_selected"
        : "winner_selected";
    await notifyOutingParticipants({
      outing,
      type: "vote",
      eventType,
      body:
        outing.vote_close_reason === "tie_break"
          ? "Yalla 5roga picked the winning place!"
          : "Voting finished — a place was selected.",
      eventKey: `${eventType}:${outing.id}:${result.winningOptionId}`,
      actionRequired: false,
    });
    await notifyOutingParticipants({
      outing,
      type: "outing",
      eventType: "outing_confirmed",
      body: `Outing "${outing.title}" is confirmed.`,
      eventKey: `outing_confirmed:${outing.id}`,
      actionRequired: false,
    });
  } else if (outcome === "cancelled") {
    await notifyOutingParticipants({
      outing,
      type: "outing",
      eventType: "outing_cancelled",
      body: `Outing "${outing.title}" was cancelled (no votes).`,
      eventKey: `outing_cancelled:${outing.id}:zero_votes`,
      actionRequired: false,
    });
  } else if (outcome === "tie") {
    await notifyOutingParticipants({
      outing,
      type: "vote",
      eventType:
        outing.vote_close_reason === "deadline"
          ? "voting_deadline_reached"
          : "voting_closed_early",
      body: `Voting tied for "${outing.title}". Waiting for the owner to decide.`,
      eventKey: `vote_tie:${outing.id}:${hashIds(result.tiedOptionIds ?? [])}`,
      actionRequired: true,
    });
  }
}

function hashIds(ids: string[]): string {
  return createHash("sha256").update(ids.slice().sort().join(",")).digest("hex").slice(0, 16);
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
