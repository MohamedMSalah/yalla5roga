import type { IOutingRepository } from "../../repositories/outings/i-outing.repository.js";
import { OutingRepository } from "../../repositories/outings/outing.repository.js";
import type { Outing } from "../../types/outings/outing.types.js";
import { assertOutingAccess } from "../../services/outings/outing-access.js";
import { NotFoundError } from "../../utils/errors.js";

export class GetOutingUseCase {
  constructor(
    private readonly outings: IOutingRepository = new OutingRepository(),
  ) {}

  async execute(id: string, callerUid?: string): Promise<Outing> {
    if (callerUid !== undefined) return assertOutingAccess(id, callerUid);
    const outing = await this.outings.findById(id);
    if (!outing) throw new NotFoundError("Outing");
    return outing;
  }
}
