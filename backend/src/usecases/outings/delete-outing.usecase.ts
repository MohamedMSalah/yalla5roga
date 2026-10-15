import type { IOutingRepository } from "../../repositories/outings/i-outing.repository.js";
import { OutingRepository } from "../../repositories/outings/outing.repository.js";
import type { Outing } from "../../types/outings/outing.types.js";
import { NotFoundError } from "../../utils/errors.js";

export class DeleteOutingUseCase {
  constructor(
    private readonly outings: IOutingRepository = new OutingRepository(),
  ) {}

  async execute(id: string): Promise<Outing> {
    const existing = await this.outings.findById(id);
    if (!existing) throw new NotFoundError("Outing");
    return this.outings.delete(id);
  }
}
