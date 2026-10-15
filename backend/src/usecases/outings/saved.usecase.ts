import type { IOutingRepository } from "../../repositories/outings/i-outing.repository.js";
import { OutingRepository } from "../../repositories/outings/outing.repository.js";
import type { SavedOuting } from "../../types/outings/outing.types.js";
import { NotFoundError } from "../../utils/errors.js";

export class ListSavedOutingsUseCase {
  constructor(
    private readonly outings: IOutingRepository = new OutingRepository(),
  ) {}

  execute(userId: string): Promise<SavedOuting[]> {
    return this.outings.listSavedByUser(userId);
  }
}

export class SaveOutingUseCase {
  constructor(
    private readonly outings: IOutingRepository = new OutingRepository(),
  ) {}

  async execute(userId: string, outingId: string): Promise<SavedOuting> {
    const outing = await this.outings.findById(outingId);
    if (!outing) throw new NotFoundError("Outing");
    return this.outings.saveOuting(userId, outingId);
  }
}

export class UnsaveOutingUseCase {
  constructor(
    private readonly outings: IOutingRepository = new OutingRepository(),
  ) {}

  execute(userId: string, outingId: string): Promise<SavedOuting> {
    return this.outings.unsaveOuting(userId, outingId);
  }
}
