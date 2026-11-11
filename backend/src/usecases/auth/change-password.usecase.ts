import type { IUserRepository } from "../../repositories/users/i-user.repository.js";
import { UserRepository } from "../../repositories/users/user.repository.js";
import { hashPassword, verifyPassword } from "../../services/auth/password.js";
import type { ChangePasswordInput } from "../../types/auth/auth.types.js";
import {
  NotFoundError,
  UnauthorizedError,
  ValidationError,
} from "../../utils/errors.js";

const INVALID_PASSWORD = "Invalid current password";
const NO_PASSWORD = "This account does not have an application password";

export class ChangePasswordUseCase {
  constructor(private readonly users: IUserRepository = new UserRepository()) {}

  async execute(input: ChangePasswordInput): Promise<void> {
    const currentPassword = input.currentPassword ?? "";
    const newPassword = input.newPassword ?? "";
    if (!currentPassword || !newPassword) {
      throw new ValidationError("currentPassword and newPassword are required");
    }
    if (newPassword.length < 6 || newPassword.length > 128) {
      throw new ValidationError("newPassword must be between 6 and 128 characters");
    }
    if (currentPassword === newPassword) {
      throw new ValidationError("newPassword must be different from currentPassword");
    }

    const user = await this.users.findById(input.userId);
    if (!user) throw new NotFoundError("User");
    if (!user.password_hash) {
      throw new ValidationError(NO_PASSWORD);
    }

    const matches = await verifyPassword(currentPassword, user.password_hash);
    if (!matches) {
      throw new UnauthorizedError(INVALID_PASSWORD);
    }

    await this.users.update(input.userId, {
      password_hash: await hashPassword(newPassword),
    });
  }
}
