import type { IUserRepository } from "../../repositories/users/i-user.repository.js";
import { UserRepository } from "../../repositories/users/user.repository.js";
import type { UpdateUserInput, User } from "../../types/users/user.types.js";
import { NotFoundError } from "../../utils/errors.js";

export class UpdateUserUseCase {
  constructor(private readonly users: IUserRepository = new UserRepository()) {}

  async execute(id: string, data: UpdateUserInput): Promise<User> {
    const existing = await this.users.findById(id);
    if (!existing) throw new NotFoundError("User");
    return this.users.update(id, data);
  }
}
