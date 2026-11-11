import { normalizePhoneNumber } from "../../services/phone/normalize-phone.js";
import type { IOutingRepository } from "../../repositories/outings/i-outing.repository.js";
import { OutingRepository } from "../../repositories/outings/outing.repository.js";
import { assertEndsAfterStart } from "../../services/outings/outing-time-window.js";
import { notifyOutingParticipants } from "../../services/notifications/outing-notifier.js";
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
    const options = input.initial_vote_options;
    if (options) {
      if (!hasGroup || hasLocation ||
          (input.status != null && input.status !== "voting")) {
        throw new ValidationError("Initial options require a group outing in voting without a fixed venue");
      }
      if (options.length < 2 || options.length > 5) {
        throw new ValidationError("Choose between two and five initial options");
      }
      const ids = new Set<string>();
      for (const option of options) {
        const { latitude, longitude, place_id } = option;
        if ((latitude == null) !== (longitude == null) ||
            (latitude != null && (!Number.isFinite(latitude) || Math.abs(latitude) > 90)) ||
            (longitude != null && (!Number.isFinite(longitude) || Math.abs(longitude) > 180))) {
          throw new ValidationError("Initial option coordinates must be a valid pair");
        }
        const name = option.label.trim().normalize("NFC").toLowerCase();
        const area = option.area?.trim().normalize("NFC").toLowerCase() ?? "";
        const id = place_id?.toLowerCase() ?? JSON.stringify([name, area, latitude ?? null, longitude ?? null]);
        if (ids.has(id)) throw new ValidationError("Duplicate initial option");
        ids.add(id);
      }
    }
    const status = options ? "voting" : input.status ?? (hasLocation ? "confirmed" : "draft");

    const phones = [...new Set((input.guest_phones ?? []).map(normalizePhoneNumber))];
    if (phones.length > 0) {
      if (hasGroup || !input.guest_phones_whatsapp_opt_in || !input.create_request_key) {
        throw new ValidationError("Phone invitations require a special event, a request key and recipient WhatsApp opt-in");
      }
      if (!input.scheduled_at || input.scheduled_at.getTime() <= Date.now() ||
          !input.location_name?.trim() || (status !== "confirmed" && status !== "draft")) {
        throw new ValidationError("Phone invitations require a future event with a fixed named venue");
      }
    }
    const outing = await this.outings.create({
      ...input,
      guest_phones: phones,
      occasion,
      type: hasGroup ? "group" : "special_event",
      status,
      image_url: input.image_url ?? "",
    });
    if (options && outing.status === "voting" && outing.vote_closed_at == null) {
      try {
        await notifyOutingParticipants({
          outing,
          type: "outing",
          eventType: "outing_updated",
          body: `Voting is open for "${outing.title}".`,
          eventKey: `outing_initial_vote_options:${outing.id}`,
          excludeUserId: input.created_by,
        });
      } catch (error) {
        console.error("[outings] initial vote option notify failed", error);
      }
    }
    return outing;
  }
}
