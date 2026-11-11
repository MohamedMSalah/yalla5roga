import type { IUserRepository } from "../../repositories/users/i-user.repository.js";
import { UserRepository } from "../../repositories/users/user.repository.js";
import { verifyPassword } from "../../services/auth/password.js";
import type { VerifyPasswordInput } from "../../types/auth/auth.types.js";
import {
  NotFoundError,
  UnauthorizedError,
  ValidationError,
} from "../../utils/errors.js";

const INVALID_PASSWORD = "Invalid password";
const NO_PASSWORD = "This account does not have an application password";

export class VerifyPasswordUseCase {
  constructor(private readonly users: IUserRepository = new UserRepository()) {}

  async execute(input: VerifyPasswordInput): Promise<void> {
    const password = input.password ?? "";
    if (!password) {
      throw new ValidationError("password is required");
    }

    const user = await this.users.findById(input.userId);
    if (!user) throw new NotFoundError("User");
    if (!user.password_hash) {
      throw new ValidationError(NO_PASSWORD);
    }

    const matches = await verifyPassword(password, user.password_hash);
    if (!matches) {
      throw new UnauthorizedError(INVALID_PASSWORD);
    }
  }
}
