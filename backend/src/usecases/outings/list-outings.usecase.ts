import type { IOutingRepository } from "../../repositories/outings/i-outing.repository.js";
import { OutingRepository } from "../../repositories/outings/outing.repository.js";
import type { Outing } from "../../types/outings/outing.types.js";

export class ListOutingsUseCase {
  constructor(
    private readonly outings: IOutingRepository = new OutingRepository(),
  ) {}

  execute(filters?: { groupId?: string; userId?: string }): Promise<Outing[]> {
    if (filters?.groupId) return this.outings.findByGroupId(filters.groupId);
    if (filters?.userId) return this.outings.findByUserId(filters.userId);
    return this.outings.findMany();
  }
}
