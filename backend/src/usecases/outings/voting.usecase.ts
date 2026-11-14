import type { Prisma } from "@prisma/client";
import { persistOutingTransition } from "../../services/notifications/outing-events.js";
import { prisma } from "../../config/database.js";
import { assertSelectablePlaces } from "../../services/places/place-selection.js";
import type { IOutingRepository } from "../../repositories/outings/i-outing.repository.js";
import { OutingRepository } from "../../repositories/outings/outing.repository.js";
import { notifyOutingParticipants } from "../../services/notifications/outing-notifier.js";
import { assertIsOutingCreator } from "../../services/outings/outing-access.js";
import { assertEligibleVoter, listEligibleVoterIds,
} from "../../services/outings/outing-participants.js";
import {
  assertCanAddVoteOption,
  assertVotingOpen,
  breakTieRandomly,
  emitResolutionNotifications,
  tryCloseIfAllVoted,
  resolveClosedVoting,
  type VoteResolutionResult,
} from "../../services/outings/vote-resolution.js";
import type {
  CreateVoteOptionInput,
  Outing,
  OutingVote,
  OutingVoteOption,
} from "../../types/outings/outing.types.js";
import { ConflictError, ForbiddenError, NotFoundError, ValidationError,
} from "../../utils/errors.js";

async function assertDeadlineOpen(outing: Outing): Promise<void> {
  if (!outing.vote_ends_at) {
    throw new ValidationError("Outing is missing a mandatory voting deadline");
  }
  if (outing.vote_ends_at.getTime() <= Date.now()) {
    throw new ConflictError("Voting deadline has passed");
  }
}

async function changeCandidates<T>(
  outingId: string,
  uid: string,
  write: (tx: Prisma.TransactionClient) => Promise<T>,
): Promise<T> {
  return prisma.$transaction(async (tx) => {
    const [outing] = await tx.$queryRaw<
      Outing[]
    >`SELECT * FROM outings WHERE id = ${outingId}::uuid FOR UPDATE`;
    if (!outing) throw new NotFoundError("Outing");
    assertIsOutingCreator(outing, uid);
    assertCanAddVoteOption(outing);
    await assertDeadlineOpen(outing);
    await tx.outing_votes.deleteMany({ where: { outing_id: outingId } });
    const result = await write(tx);
    const updated = await tx.outings.update({
      where: { id: outingId },
      data: {
        status: outing.status === "draft" ? "voting" : outing.status,
        updated_at: new Date(
          Math.max(Date.now(), outing.updated_at.getTime() + 1),
        ),
      },
    });
    await persistOutingTransition(tx, outing, updated);
    await notifyOutingParticipants(
      {
        outing: updated,
        type: "vote",
        eventType: "outing_updated",
        body: `Voting options for "${outing.title}" changed. Votes were reset � please vote again.`,
        eventKey: `vote_options_reset:${outingId}:${updated.updated_at.toISOString()}`,
        excludeUserId: uid,
        data: { navigationSection: "voting" },
      },
      tx,
    );
    return result;
  });
}

export class ListVoteOptionsUseCase {
  constructor(
    private readonly outings: IOutingRepository = new OutingRepository(),
  ) {}

  async execute(outingId: string): Promise<OutingVoteOption[]> {
    const outing = await this.outings.findById(outingId);
    if (!outing) throw new NotFoundError("Outing");
    return this.outings.listVoteOptions(outingId);
  }
}

export class CreateVoteOptionUseCase {
  constructor(
    private readonly outings: IOutingRepository = new OutingRepository(),
  ) {}

  async execute(
    callerUid: string,
    input: Omit<CreateVoteOptionInput, "outing_id"> & { outing_id: string },
  ): Promise<OutingVoteOption> {
    if (!input.label) throw new ValidationError("label is required");
    const outing = await this.outings.findById(input.outing_id);
    if (!outing) throw new NotFoundError("Outing");
    assertIsOutingCreator(outing, callerUid);
    assertCanAddVoteOption(outing);
    await assertDeadlineOpen(outing);

    return changeCandidates(outing.id, callerUid, async (tx) => {
      await assertSelectablePlaces(tx, [input.place_id]);
      return tx.outing_vote_options.create({ data: input });
    });
  }
}

export class DeleteVoteOptionUseCase {
  constructor(
    private readonly outings: IOutingRepository = new OutingRepository(),
  ) {}

  async execute(
    optionId: string,
    callerUid: string,
    outingId?: string,
  ): Promise<OutingVoteOption> {
    const option = await this.outings.findVoteOptionById(optionId);
    if (!option || (outingId && option.outing_id !== outingId)) throw new NotFoundError("Vote option");

    const outing = await this.outings.findById(option.outing_id);
    if (!outing) throw new NotFoundError("Outing");
    assertIsOutingCreator(outing, callerUid);
    assertCanAddVoteOption(outing);
    await assertDeadlineOpen(outing);

    return changeCandidates(outing.id, callerUid, (tx) =>
      tx.outing_vote_options.delete({ where: { id: optionId } }),
    );
  }
}

export class ReplaceVoteOptionsUseCase {
  constructor(
    private readonly outings: IOutingRepository = new OutingRepository(),
  ) {}

  async execute(
    outingId: string,
    callerUid: string,
    options: Array<Omit<CreateVoteOptionInput, "outing_id">>,
  ): Promise<OutingVoteOption[]> {
    if (!options.length) {
      throw new ValidationError("At least one vote option is required");
    }
    const outing = await this.outings.findById(outingId);
    if (!outing) throw new NotFoundError("Outing");
    assertIsOutingCreator(outing, callerUid);
    assertCanAddVoteOption(outing);
    await assertDeadlineOpen(outing);

    return changeCandidates(outingId, callerUid, async (tx) => {
      await assertSelectablePlaces(
        tx,
        options.map((o) => o.place_id),
      );
      await tx.outing_vote_options.deleteMany({ where: { outing_id: outingId },
      });

      const rows: OutingVoteOption[] = [];
      for (let i = 0; i < options.length; i ++) {
        const option = options[i]!;
        if (!option.label) throw new ValidationError("label is required");
        rows.push(
          await tx.outing_vote_options.create({
            data: {
              ...option,
              outing_id: outingId,
              sort_order: option.sort_order ?? i,
            },
          }),
        );
      }
      return rows;
    });
  }
}

export class ListVotesUseCase {
  constructor(
    private readonly outings: IOutingRepository = new OutingRepository(),
  ) {}

  async execute(outingId: string): Promise<OutingVote[]> {
    const outing = await this.outings.findById(outingId);
    if (!outing) throw new NotFoundError("Outing");
    return this.outings.listVotes(outingId);
  }
}

export class CastVoteUseCase {
  constructor(
    private readonly outings: IOutingRepository = new OutingRepository(),
  ) {}

  async execute(
    outingId: string,
    userId: string,
    optionId: string,
  ): Promise<{ vote: OutingVote; resolution: VoteResolutionResult | null }> {
    if (!optionId) throw new ValidationError("option_id is required");
    const outing = await this.outings.findById(outingId);
    if (!outing) throw new NotFoundError("Outing");
    assertVotingOpen(outing);
    await assertEligibleVoter(outing, userId);

    const option = await this.outings.findVoteOptionById(optionId);
    if (!option || option.outing_id !== outingId) {
      throw new NotFoundError("Vote option");
    }

    const vote = await this.outings.castVote({
      outing_id: outingId,
      user_id: userId,
      option_id: optionId,
    });

    const resolution = await tryCloseIfAllVoted(outingId);
    if (resolution) {
      await emitResolutionNotifications(resolution);
    }

    return { vote, resolution };
  }
}

/** Replace a complete ballot before evaluating early closure. */
export class ReplaceBallotUseCase {
  async execute(outingId: string, userId: string, optionIds: string[]) {
    if (!Array.isArray(optionIds) || optionIds.length > 5 || new Set(optionIds).size !== optionIds.length) {
      throw new ValidationError("Select up to five distinct options");
    }
    const result = await prisma.$transaction(async (tx) => {
      const [outing] = await tx.$queryRaw<Outing[]>`SELECT * FROM outings WHERE id = ${outingId}::uuid FOR UPDATE`;
      if (!outing) throw new NotFoundError("Outing");
      assertVotingOpen(outing);
      await assertDeadlineOpen(outing);
      const eligible = await listEligibleVoterIds(outing, tx);
      if (!eligible.includes(userId)) throw new ForbiddenError("Only outing members can vote");
      const options = await tx.outing_vote_options.findMany({ where: { outing_id: outingId, id: { in: optionIds } },
      });
      if (options.length !== optionIds.length) throw new ValidationError("Every option must belong to this outing");
      await tx.outing_votes.deleteMany({ where: { outing_id: outingId, user_id: userId },
      });
      if (optionIds.length) await tx.outing_votes.createMany({ data: optionIds.map((option_id) => ({ outing_id: outingId, user_id: userId, option_id,
          })),
        });
      const votes = await tx.outing_votes.findMany({ where: { outing_id: outingId },
      });
      const voters = new Set(votes.map((vote) => vote.user_id));
      const resolution = eligible.length && eligible.every((id) => voters.has(id))
        ? await resolveClosedVoting(tx, outing, "all_voted") : null;
      return { votes: votes.filter((vote) => vote.user_id === userId), resolution,
      };
    });
    if (result.resolution) await emitResolutionNotifications(result.resolution);
    return result;
  }
}

export class RemoveVoteUseCase {
  constructor(
    private readonly outings: IOutingRepository = new OutingRepository(),
  ) {}

  async execute(outingId: string, userId: string, optionId?: string,
  ): Promise<OutingVote> {
    const outing = await this.outings.findById(outingId);
    if (!outing) throw new NotFoundError("Outing");
    assertVotingOpen(outing);
    await assertEligibleVoter(outing, userId);
    return this.outings.removeVote(outingId, userId, optionId);
  }
}

export class TieBreakUseCase {
  async execute(
    outingId: string,
    callerUid: string,
  ): Promise<VoteResolutionResult> {
    const result = await breakTieRandomly(outingId, callerUid);
    await emitResolutionNotifications(result);
    return result;
  }
}

export class GetVotingStateUseCase {
  constructor(
    private readonly outings: IOutingRepository = new OutingRepository(),
  ) {}

  async execute(outingId: string): Promise<{
    outing: Outing;
    options: OutingVoteOption[];
    votes: OutingVote[];
    tiedOptionIds: string[];
    eligible_voter_count: number;
    isTied: boolean;
    isClosed: boolean;
  }> {
    const outing = await this.outings.findById(outingId);
    if (!outing) throw new NotFoundError("Outing");
    const [options, votes, voters] = await Promise.all([
      this.outings.listVoteOptions(outingId),
      this.outings.listVotes(outingId),
      listEligibleVoterIds(outing),
    ]);

    const counts = new Map<string, number>();
    for (const vote of votes) {
      counts.set(vote.option_id, (counts.get(vote.option_id) ?? 0) + 1);
    }
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

    const isClosed = Boolean(outing.vote_closed_at);
    const isTied =
      isClosed &&
      outing.status === "voting" &&
      !outing.winning_option_id &&
      leaders.length > 1;

    return {
      outing,
      options,
      votes,
      tiedOptionIds: isTied ? leaders : [],
      eligible_voter_count: voters.length,
      isTied,
      isClosed,
    };
  }
}

export class CancelOutingUseCase {
  constructor(
    private readonly outings: IOutingRepository = new OutingRepository(),
  ) {}

  async execute(outingId: string, callerUid: string): Promise<Outing> {
    const outing = await this.outings.findById(outingId);
    if (!outing) throw new NotFoundError("Outing");
    assertIsOutingCreator(outing, callerUid);
    if (outing.status === "cancelled") return outing;
    if (outing.status === "past") {
      throw new ConflictError("Past outings cannot be cancelled");
    }
    const cancelled = await this.outings.update(outingId, { status: "cancelled",
    });

    return cancelled;
  }
}
