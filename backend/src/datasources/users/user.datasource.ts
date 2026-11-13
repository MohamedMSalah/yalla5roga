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

  findByPhone(phone: string): Promise<User | null> {
    return prisma.users.findUnique({ where: { phone } });
  }

  /**
   * Registration-safe phone lookup: only matches a profile that shares an
   * active group with the caller. Callers without a group, and phones that do
   * not belong to a co-member, return null — so the endpoint cannot be used to
   * test whether an arbitrary number is registered.
   */
  async findByPhoneInSharedGroup(
    phone: string,
    callerUid: string,
  ): Promise<User | null> {
    const memberships = await prisma.group_members.findMany({
      where: { user_id: callerUid },
      select: { group_id: true },
    });
    if (memberships.length === 0) return null;

    return prisma.users.findFirst({
      where: {
        phone,
        group_members: {
          some: { group_id: { in: memberships.map((row) => row.group_id) } },
        },
      },
    });
  }

  findMany(): Promise<User[]> {
    return prisma.users.findMany({ orderBy: { created_at: "desc" } });
  }

  findManyByIds(ids: string[]): Promise<User[]> {
    if (ids.length === 0) return Promise.resolve([]);
    return prisma.users.findMany({
      where: { id: { in: ids } },
      orderBy: { created_at: "desc" },
    });
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

  async enrollPassword(id: string, phone: string, passwordHash: string): Promise<User | null> {
    const [updated] = await prisma.users.updateManyAndReturn({
      where: { id, phone, password_hash: null },
      data: { password_hash: passwordHash },
    });
    return updated ?? this.findById(id);
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
