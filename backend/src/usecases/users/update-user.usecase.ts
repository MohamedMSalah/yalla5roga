import type { IUserRepository } from "../../repositories/users/i-user.repository.js";
import { UserRepository } from "../../repositories/users/user.repository.js";
import { MediaService } from "../../services/media/media.service.js";
import type { UpdateUserInput, User } from "../../types/users/user.types.js";
import { NotFoundError, ValidationError } from "../../utils/errors.js";
import { truncateDisplayName } from "./sync-user.usecase.js";

/**
 * Application profile updates for the authenticated user.
 * Does not change Firebase UID, role, or privileged identity fields.
 * Verified phone changes go through SyncUserUseCase.
 */
export class UpdateUserUseCase {
  constructor(
    private readonly users: IUserRepository = new UserRepository(),
    private readonly media = new MediaService(),
  ) {}

  async execute(id: string, data: UpdateUserInput): Promise<User> {
    const existing = await this.users.findById(id);
    if (!existing) throw new NotFoundError("User");

    const patch: UpdateUserInput = {};

    if (data.name !== undefined) {
      const name = truncateDisplayName(data.name);
      if (!name) throw new ValidationError("name is required");
      patch.name = name;
    }

    if (data.image_url !== undefined) {
      // `media://<id>` references are verified (ownership + ready) and linked
      // to this profile; plain http(s) URLs pass through unchanged.
      patch.image_url = await this.media.resolveEntityImage({
        uid: id,
        imageValue: data.image_url,
        purpose: "profile",
        link: { user_id: id },
      });
    }

    if (data.phone !== undefined) {
      throw new ValidationError("Phone changes require Firebase verification and POST /api/users/sync");
    }

    if (Object.keys(patch).length === 0) {
      return existing;
    }

    return this.users.update(id, patch);
  }
}
