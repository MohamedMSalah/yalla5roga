import type {
  CreateUserInput,
  UpdateUserInput,
  User,
} from "../../types/users/user.types.js";

export interface IUserRepository {
  findById(id: string): Promise<User | null>;
  findByPhone(phone: string): Promise<User | null>;
  /**
   * Phone lookup restricted to users who share an active group with the
   * caller. Used by the directory endpoint so arbitrary phone numbers cannot
   * be tested for registration.
   */
  findByPhoneInSharedGroup(phone: string, callerUid: string): Promise<User | null>;
  findMany(): Promise<User[]>;
  findManyByIds(ids: string[]): Promise<User[]>;
  create(data: CreateUserInput): Promise<User>;
  update(id: string, data: UpdateUserInput): Promise<User>;
  enrollPassword(id: string, phone: string, passwordHash: string): Promise<User | null>;
  sync(data: CreateUserInput): Promise<User>;
  delete(id: string): Promise<User>;
}
