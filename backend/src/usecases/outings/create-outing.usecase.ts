import type { IOutingRepository } from "../../repositories/outings/i-outing.repository.js";
import { OutingRepository } from "../../repositories/outings/outing.repository.js";
import { assertEndsAfterStart } from "../../services/outings/outing-time-window.js";
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

    const occasion = input.occasion ?? "none";
    const hasGroup = input.group_id != null;
    if (hasGroup && occasion !== "none") {
      throw new ValidationError("group outings must use occasion 'none'");
    }
    if (!hasGroup && occasion === "none") {
      throw new ValidationError(
        "provide group_id for a group outing, or set occasion to 'birthday' or 'wedding' for a special event",
      );
    }

    assertEndsAfterStart(input.scheduled_at, input.ends_at);

    return this.outings.create({
      ...input,
      occasion,
      image_url: input.image_url ?? "",
    });
  }
}
