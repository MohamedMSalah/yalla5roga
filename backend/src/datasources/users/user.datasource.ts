import { prisma } from "../../config/database.js";
import type {
  CreateUserInput,
  UpdateUserInput,
  User,
} from "../../types/users/user.types.js";

export class UserDatasource {
  findById(id: string): Promise<User | null> {
    return prisma.users.findUnique({ where: { id } });
  }

  findByEmail(email: string): Promise<User | null> {
    return prisma.users.findUnique({ where: { email } });
  }

  findByPhone(phone: string): Promise<User | null> {
    return prisma.users.findUnique({ where: { phone } });
  }

  findMany(): Promise<User[]> {
    return prisma.users.findMany({ orderBy: { created_at: "desc" } });
  }

  create(data: CreateUserInput): Promise<User> {
    return prisma.users.create({ data });
  }

  update(id: string, data: UpdateUserInput): Promise<User> {
    return prisma.users.update({
      where: { id },
      data: { ...data, updated_at: new Date() },
    });
  }

  /**
   * Legacy helper. Prefer create + selective update from SyncUserUseCase so
   * existing profile fields are not overwritten by identity sync.
   */
  upsert(data: CreateUserInput): Promise<User> {
    return prisma.users.upsert({
      where: { id: data.id },
      create: data,
      update: {
        updated_at: new Date(),
      },
    });
  }

  delete(id: string): Promise<User> {
    return prisma.users.delete({ where: { id } });
  }
}
