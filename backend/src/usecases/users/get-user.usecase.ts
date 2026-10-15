import type { IUserRepository } from "../../repositories/users/i-user.repository.js";
import { UserRepository } from "../../repositories/users/user.repository.js";
import type { User } from "../../types/users/user.types.js";
import { NotFoundError } from "../../utils/errors.js";

export class GetUserUseCase {
  constructor(private readonly users: IUserRepository = new UserRepository()) {}

  async execute(id: string): Promise<User> {
    const user = await this.users.findById(id);
    if (!user) throw new NotFoundError("User");
    return user;
  }
}
