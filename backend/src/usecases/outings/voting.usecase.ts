import { prisma } from "../../config/database.js";
import type { IOutingRepository } from "../../repositories/outings/i-outing.repository.js";
import { OutingRepository } from "../../repositories/outings/outing.repository.js";
import { notifyOutingParticipants } from "../../services/notifications/outing-notifier.js";
import { assertIsOutingCreator } from "../../services/outings/outing-access.js";
import { assertEligibleVoter, listEligibleVoterIds } from "../../services/outings/outing-participants.js";
import {
  assertCanAddVoteOption,
  assertVotingOpen,
  breakTieRandomly,
  emitResolutionNotifications,
  tryCloseIfAllVoted,
  type VoteResolutionResult,
} from "../../services/outings/vote-resolution.js";
import type {
  CreateVoteOptionInput,
  Outing,
  OutingVote,
  OutingVoteOption,
} from "../../types/outings/outing.types.js";
import { ConflictError, NotFoundError, ValidationError } from "../../utils/errors.js";

async function assertDeadlineOpen(outing: Outing): Promise<void> {
  if (!outing.vote_ends_at) {
    throw new ValidationError("Outing is missing a mandatory voting deadline");
  }
  if (outing.vote_ends_at.getTime() <= Date.now()) {
    throw new ConflictError("Voting deadline has passed");
  }
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

    const option = await this.outings.createVoteOption(input);
    await this.outings.clearVotes(outing.id);
    if (outing.status === "draft") {
      await this.outings.update(outing.id, { status: "voting" });
    }

    try {
      await notifyOutingParticipants({
        outing,
        type: "outing",
        eventType: "outing_updated",
        body: `Voting options for "${outing.title}" changed. Votes were reset — please vote again.`,
        eventKey: `vote_options_reset:${outing.id}:${option.id}`,
        excludeUserId: callerUid,
      });
    } catch (error) {
      console.error("[outings] vote option notify failed", error);
    }

    return option;
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

    await this.outings.clearVotes(outing.id);
    const deleted = await this.outings.deleteVoteOption(optionId);

    try {
      await notifyOutingParticipants({
        outing,
        type: "outing",
        eventType: "outing_updated",
        body: `Voting options for "${outing.title}" changed. Votes were reset — please vote again.`,
        eventKey: `vote_options_reset:${outing.id}:del:${optionId}`,
        excludeUserId: callerUid,
      });
    } catch (error) {
      console.error("[outings] vote option delete notify failed", error);
    }

    return deleted;
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

    const preservedDeadline = outing.vote_ends_at;

    const created = await prisma.$transaction(async (tx) => {
      await tx.outing_votes.deleteMany({ where: { outing_id: outingId } });
      await tx.outing_vote_options.deleteMany({ where: { outing_id: outingId } });

      const rows: OutingVoteOption[] = [];
      for (let i = 0; i < options.length; i += 1) {
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

      await tx.outings.update({
        where: { id: outingId },
        data: {
          status: outing.status === "draft" ? "voting" : outing.status,
          vote_ends_at: preservedDeadline,
          updated_at: new Date(),
        },
      });

      return rows;
    });

    await notifyOutingParticipants({
      outing,
      type: "outing",
      eventType: "outing_updated",
      body: `Voting options for "${outing.title}" changed. Votes were reset — please vote again.`,
      eventKey: `vote_options_replace:${outingId}:${created.map((o) => o.id).join(",")}`,
      excludeUserId: callerUid,
    });

    return created;
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

export class RemoveVoteUseCase {
  constructor(
    private readonly outings: IOutingRepository = new OutingRepository(),
  ) {}

  async execute(outingId: string, userId: string, optionId?: string): Promise<OutingVote> {
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
    private readonly notify: typeof notifyOutingParticipants = notifyOutingParticipants,
  ) {}

  async execute(outingId: string, callerUid: string): Promise<Outing> {
    const outing = await this.outings.findById(outingId);
    if (!outing) throw new NotFoundError("Outing");
    assertIsOutingCreator(outing, callerUid);
    if (outing.status === "cancelled") return outing;
    if (outing.status === "past") {
      throw new ConflictError("Past outings cannot be cancelled");
    }
    const cancelled = await this.outings.update(outingId, { status: "cancelled" });

    // Notify participants after the persisted transition. The event key is
    // stable (`:owner`) and shared with the PATCH status=cancelled path, so a
    // repeated cancel or a mixed PATCH/POST cancel cannot fan out twice:
    // notifications.event_key is unique and inserts use skipDuplicates.
    await this.notify({
      outing: cancelled,
      type: "outing",
      eventType: "outing_cancelled",
      body: `Outing "${cancelled.title}" was cancelled.`,
      eventKey: `outing_cancelled:${cancelled.id}:owner`,
      excludeUserId: callerUid,
    });

    return cancelled;
  }
}
