import type { IOutingRepository } from "../../repositories/outings/i-outing.repository.js";
import { OutingRepository } from "../../repositories/outings/outing.repository.js";
import type {
  CreateVoteOptionInput,
  OutingVote,
  OutingVoteOption,
} from "../../types/outings/outing.types.js";
import { NotFoundError, ValidationError } from "../../utils/errors.js";

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
    input: Omit<CreateVoteOptionInput, "outing_id"> & { outing_id: string },
  ): Promise<OutingVoteOption> {
    if (!input.label) throw new ValidationError("label is required");
    const outing = await this.outings.findById(input.outing_id);
    if (!outing) throw new NotFoundError("Outing");
    return this.outings.createVoteOption(input);
  }
}

export class DeleteVoteOptionUseCase {
  constructor(
    private readonly outings: IOutingRepository = new OutingRepository(),
  ) {}

  execute(optionId: string): Promise<OutingVoteOption> {
    return this.outings.deleteVoteOption(optionId);
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
  ): Promise<OutingVote> {
    if (!optionId) throw new ValidationError("option_id is required");
    const outing = await this.outings.findById(outingId);
    if (!outing) throw new NotFoundError("Outing");
    return this.outings.castVote({
      outing_id: outingId,
      user_id: userId,
      option_id: optionId,
    });
  }
}

export class RemoveVoteUseCase {
  constructor(
    private readonly outings: IOutingRepository = new OutingRepository(),
  ) {}

  execute(
    outingId: string,
    userId: string,
    optionId: string,
  ): Promise<OutingVote> {
    return this.outings.removeVote(outingId, userId, optionId);
  }
}
