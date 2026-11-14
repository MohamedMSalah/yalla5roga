import type { IOutingRepository } from "../../repositories/outings/i-outing.repository.js";
import { OutingRepository } from "../../repositories/outings/outing.repository.js";
import { MediaService } from "../../services/media/media.service.js";
import { assertIsOutingCreator } from "../../services/outings/outing-access.js";
import { assertEndsAfterStart } from "../../services/outings/outing-time-window.js";
import { assertValidStatusTransition } from "../../services/outings/vote-resolution.js";
import type {
  Outing,
  UpdateOutingInput,
} from "../../types/outings/outing.types.js";
import { ConflictError, NotFoundError, ValidationError,
} from "../../utils/errors.js";

export class UpdateOutingUseCase {
  constructor(
    private readonly outings: IOutingRepository = new OutingRepository(),
    private readonly media = new MediaService(),
  ) {}

  async execute(
    id: string,
    callerUid: string,
    data: UpdateOutingInput,
  ): Promise<Outing> {
    const existing = await this.outings.findById(id);
    if (!existing) throw new NotFoundError("Outing");
    assertIsOutingCreator(existing, callerUid);

    if (existing.status === "cancelled" || existing.status === "past") {
      throw new ConflictError("Cannot edit a closed outing");
    }

    // Members cannot edit; owner can edit after confirmation.
    // Clients must not force vote closure or reopen voting via PATCH.
    if ("vote_closed_at" in data || "winning_option_id" in data || "vote_close_reason" in data) {
      throw new ValidationError(
        "Vote closure and winner selection are server-controlled",
      );
    }

    // Confirmed winning place is immutable (product scenario §3.9).
    if (existing.status === "confirmed" || existing.winning_option_id != null) {
      const locationTouched =
        data.location_place_id !== undefined ||
        data.location_name !== undefined ||
        data.location_area !== undefined ||
        data.location_latitude !== undefined ||
        data.location_longitude !== undefined;
      if (locationTouched) {
        throw new ConflictError(
          "Confirmed winning place cannot be changed");
      }
    }

    if (data.status != null && data.status !== existing.status) {
      if (data.status === "confirmed") {
        throw new ValidationError("Confirm a proposed venue through the venue confirmation endpoint",
        );
      }
      assertValidStatusTransition(existing.status, data.status);
      if (data.status === "voting" && existing.status === "confirmed") {
        throw new ValidationError("Confirmed outings cannot reopen voting");
      }
    }

    const scheduledAt =
      data.scheduled_at !== undefined ? data.scheduled_at : existing.scheduled_at;
    const endsAt = data.ends_at !== undefined ? data.ends_at : existing.ends_at;
    assertEndsAfterStart(scheduledAt, endsAt);

    const groupId =
      data.group_id !== undefined ? data.group_id : existing.group_id;
    const occasion =
      data.occasion !== undefined ? data.occasion : existing.occasion;
    const hasGroup = groupId != null;
    if (!hasGroup && occasion === "none") {
      throw new ValidationError(
        "provide group_id for a group outing, or set a special-event occasion (birthday, wedding, celebration, other)",
      );
    }

    const patch = { ...data };
    if (data.image_url !== undefined) {
      patch.image_url =
        (await this.media.resolveEntityImage({
        uid: callerUid,
        imageValue: data.image_url,
        purpose: "outing",
        link: { outing_id: id },
      })) ?? undefined;
    }

    const updated = await this.outings.update(id, {
      ...patch,
      type: occasion === "none" ? "group" : "special_event",
    });

    return updated;
  }
}
