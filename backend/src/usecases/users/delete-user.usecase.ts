import type { IUserRepository } from "../../repositories/users/i-user.repository.js";
import { UserRepository } from "../../repositories/users/user.repository.js";
import type { User } from "../../types/users/user.types.js";
import { NotFoundError } from "../../utils/errors.js";

export class DeleteUserUseCase {
  constructor(private readonly users: IUserRepository = new UserRepository()) {}

  async execute(id: string): Promise<User> {
    const existing = await this.users.findById(id);
    if (!existing) throw new NotFoundError("User");
    return this.users.delete(id);
  }
}
