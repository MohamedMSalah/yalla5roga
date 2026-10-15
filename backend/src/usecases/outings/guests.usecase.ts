import type { IOutingRepository } from "../../repositories/outings/i-outing.repository.js";
import { OutingRepository } from "../../repositories/outings/outing.repository.js";
import type { OutingGuest } from "../../types/outings/outing.types.js";
import { NotFoundError, ValidationError } from "../../utils/errors.js";

export class ListGuestsUseCase {
  constructor(
    private readonly outings: IOutingRepository = new OutingRepository(),
  ) {}

  async execute(outingId: string): Promise<OutingGuest[]> {
    const outing = await this.outings.findById(outingId);
    if (!outing) throw new NotFoundError("Outing");
    return this.outings.listGuests(outingId);
  }
}

export class AddGuestUseCase {
  constructor(
    private readonly outings: IOutingRepository = new OutingRepository(),
  ) {}

  async execute(outingId: string, userId: string): Promise<OutingGuest> {
    if (!userId) throw new ValidationError("user_id is required");
    const outing = await this.outings.findById(outingId);
    if (!outing) throw new NotFoundError("Outing");
    return this.outings.addGuest({ outing_id: outingId, user_id: userId });
  }
}

export class RemoveGuestUseCase {
  constructor(
    private readonly outings: IOutingRepository = new OutingRepository(),
  ) {}

  async execute(outingId: string, userId: string): Promise<OutingGuest> {
    const outing = await this.outings.findById(outingId);
    if (!outing) throw new NotFoundError("Outing");
    return this.outings.removeGuest(outingId, userId);
  }
}
