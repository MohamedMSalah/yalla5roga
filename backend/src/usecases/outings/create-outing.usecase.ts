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

    if (input.vote_ends_at == null && input.vote_deadline_hours == null) {
      throw new ValidationError(
        "voting deadline is required: provide vote_ends_at or vote_deadline_hours",
      );
    }

    const hasLocation = Boolean(input.location_place_id || input.location_name);
    const status =
      input.status ??
      (hasLocation ? "confirmed" : "draft");

    return this.outings.create({
      ...input,
      occasion,
      type: hasGroup ? "group" : "special_event",
      status,
      image_url: input.image_url ?? "",
    });
  }
}
