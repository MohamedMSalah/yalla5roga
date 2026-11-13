import { UserDatasource } from "../../datasources/users/user.datasource.js";
import type {
  CreateUserInput,
  UpdateUserInput,
  User,
} from "../../types/users/user.types.js";
import type { IUserRepository } from "./i-user.repository.js";

export class UserRepository implements IUserRepository {
  constructor(private readonly datasource = new UserDatasource()) {}

  findById(id: string): Promise<User | null> {
    return this.datasource.findById(id);
  }

  findByPhone(phone: string): Promise<User | null> {
    return this.datasource.findByPhone(phone);
  }

  findByPhoneInSharedGroup(phone: string, callerUid: string): Promise<User | null> {
    return this.datasource.findByPhoneInSharedGroup(phone, callerUid);
  }

  findMany(): Promise<User[]> {
    return this.datasource.findMany();
  }

  findManyByIds(ids: string[]): Promise<User[]> {
    return this.datasource.findManyByIds(ids);
  }

  create(data: CreateUserInput): Promise<User> {
    return this.datasource.create(data);
  }

  update(id: string, data: UpdateUserInput): Promise<User> {
    return this.datasource.update(id, data);
  }

  enrollPassword(id: string, phone: string, passwordHash: string): Promise<User | null> {
    return this.datasource.enrollPassword(id, phone, passwordHash);
  }

  sync(data: CreateUserInput): Promise<User> {
    return this.datasource.upsert(data);
  }

  delete(id: string): Promise<User> {
    return this.datasource.delete(id);
  }
}
