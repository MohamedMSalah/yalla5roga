import type { IOutingRepository } from "../../repositories/outings/i-outing.repository.js";
import { OutingRepository } from "../../repositories/outings/outing.repository.js";
import type {
  CreateOutingInput,
  Outing,
} from "../../types/outings/outing.types.js";
import { ValidationError } from "../../utils/errors.js";

export class CreateOutingUseCase {
  constructor(
    private readonly outings: IOutingRepository = new OutingRepository(),
  ) {}

  async execute(input: CreateOutingInput): Promise<Outing> {
    if (!input.title || !input.created_by) {
      throw new ValidationError("title and created_by are required");
    }

    return this.outings.create(input);
  }
}
