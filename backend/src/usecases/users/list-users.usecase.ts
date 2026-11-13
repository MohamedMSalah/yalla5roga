import type { IUserRepository } from "../../repositories/users/i-user.repository.js";
import { UserRepository } from "../../repositories/users/user.repository.js";
import type { User } from "../../types/users/user.types.js";

/**
 * Directory lookup by exact identifiers. There is intentionally no
 * "list every profile" operation: an unscoped list leaks the whole user base.
 *
 * Phone lookups are scoped to users who share an active group with the caller.
 * That keeps member discovery working without turning the endpoint into a
 * registration oracle: an arbitrary phone returns the same empty result
 * whether it belongs to nobody or to an unrelated account.
 */
export class ListUsersUseCase {
  constructor(private readonly users: IUserRepository = new UserRepository()) {}

  executeByIds(ids: string[]): Promise<User[]> {
    return this.users.findManyByIds(ids);
  }

  async executeByPhone(phone: string, callerUid: string): Promise<User[]> {
    const user = await this.users.findByPhoneInSharedGroup(phone, callerUid);
    return user ? [user] : [];
  }
}
