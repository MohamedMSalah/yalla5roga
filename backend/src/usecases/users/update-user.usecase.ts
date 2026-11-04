import type { IUserRepository } from "../../repositories/users/i-user.repository.js";
import { UserRepository } from "../../repositories/users/user.repository.js";
import { normalizePhoneNumber } from "../../services/phone/normalize-phone.js";
import type { UpdateUserInput, User } from "../../types/users/user.types.js";
import { ConflictError, NotFoundError, ValidationError } from "../../utils/errors.js";
import { truncateDisplayName } from "./sync-user.usecase.js";

const PHONE_ALREADY_LINKED =
  "This phone number is already associated with another account";

/**
 * Application profile updates for the authenticated user.
 * Does not change Firebase UID, role, or privileged identity fields.
 * A phone set here is a profile value only — it is not treated as verified.
 */
export class UpdateUserUseCase {
  constructor(private readonly users: IUserRepository = new UserRepository()) {}

  async execute(id: string, data: UpdateUserInput): Promise<User> {
    const existing = await this.users.findById(id);
    if (!existing) throw new NotFoundError("User");

    const patch: UpdateUserInput = {};

    if (data.name !== undefined) {
      const name = truncateDisplayName(data.name);
      if (!name) throw new ValidationError("name is required");
      patch.name = name;
    }

    if (data.email !== undefined) {
      patch.email = data.email;
    }

    if (data.image_url !== undefined) {
      patch.image_url = data.image_url;
    }

    if (data.phone !== undefined) {
      if (data.phone === null || data.phone === "") {
        patch.phone = null;
      } else {
        const phone = normalizePhoneNumber(data.phone);
        const owner = await this.users.findByPhone(phone);
        if (owner && owner.id !== id) {
          throw new ConflictError(PHONE_ALREADY_LINKED);
        }
        patch.phone = phone;
      }
    }

    if (Object.keys(patch).length === 0) {
      return existing;
    }

    return this.users.update(id, patch);
  }
}
