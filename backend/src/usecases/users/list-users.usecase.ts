import type { IUserRepository } from "../../repositories/users/i-user.repository.js";
import { UserRepository } from "../../repositories/users/user.repository.js";
import type { User } from "../../types/users/user.types.js";

export class ListUsersUseCase {
  constructor(private readonly users: IUserRepository = new UserRepository()) {}

  execute(): Promise<User[]> {
    return this.users.findMany();
  }
}
