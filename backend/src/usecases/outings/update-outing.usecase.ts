import type { IOutingRepository } from "../../repositories/outings/i-outing.repository.js";
import { OutingRepository } from "../../repositories/outings/outing.repository.js";
import type {
  Outing,
  UpdateOutingInput,
} from "../../types/outings/outing.types.js";
import { NotFoundError } from "../../utils/errors.js";

export class UpdateOutingUseCase {
  constructor(
    private readonly outings: IOutingRepository = new OutingRepository(),
  ) {}

  async execute(id: string, data: UpdateOutingInput): Promise<Outing> {
    const existing = await this.outings.findById(id);
    if (!existing) throw new NotFoundError("Outing");
    return this.outings.update(id, data);
  }
}
