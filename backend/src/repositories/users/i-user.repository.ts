import type {
  CreateUserInput,
  UpdateUserInput,
  User,
} from "../../types/users/user.types.js";

export interface IUserRepository {
  findById(id: string): Promise<User | null>;
  findByPhone(phone: string): Promise<User | null>;
  findMany(): Promise<User[]>;
  create(data: CreateUserInput): Promise<User>;
  update(id: string, data: UpdateUserInput): Promise<User>;
  sync(data: CreateUserInput): Promise<User>;
  delete(id: string): Promise<User>;
}
