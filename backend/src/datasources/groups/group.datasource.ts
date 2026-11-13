import type { Prisma, PrismaClient, group_role } from "@prisma/client";
import { prisma } from "../../config/database.js";
import { addInvitedGroupMember } from "./group-membership.js";
import { ConflictError, ForbiddenError, NotFoundError } from "../../utils/errors.js";
import type {
  AddGroupMemberInput,
  CreateGroupInput,
  Group,
  GroupMember,
  GroupMemberView,
  GroupRoster,
  UpdateGroupInput,
} from "../../types/groups/group.types.js";

type GroupCountRow = {
  id: string;
  name: string;
  bio: string;
  image_url: string;
  created_by: string;
  created_at: Date;
  updated_at: Date;
  _count: { group_members: number };
  group_members?: Array<{ role: group_role }>;
};

function mapGroup(row: GroupCountRow): Group {
  const { _count, group_members, ...group } = row;
  return {
    ...group,
    member_count: _count.group_members,
    ...(group_members?.[0]?.role ? { my_role: group_members[0].role } : {}),
  };
}

const groupWithCount = {
  _count: { select: { group_members: true } },
} as const;

export class GroupDatasource {
  constructor(private readonly db: PrismaClient | Prisma.TransactionClient = prisma) {}
  findById(id: string): Promise<Group | null> {
    return this.db.groups
      .findUnique({
        where: { id },
        include: groupWithCount,
      })
      .then((row) => (row ? mapGroup(row) : null));
  }

  findMany(): Promise<Group[]> {
    return this.db.groups
      .findMany({
        orderBy: { created_at: "desc" },
        include: groupWithCount,
      })
      .then((rows) => rows.map(mapGroup));
  }

  findByUserId(userId: string): Promise<Group[]> {
    return this.db.groups
      .findMany({
        where: { group_members: { some: { user_id: userId } } },
        orderBy: { updated_at: "desc" },
        include: {
          ...groupWithCount,
          group_members: {
            where: { user_id: userId },
            select: { role: true },
            take: 1,
          },
        },
      })
      .then((rows) => rows.map(mapGroup));
  }

  create(data: CreateGroupInput): Promise<Group> {
    const { created_by, ...profile } = data;
    return this.db.groups.create({
      data: {
        ...profile,
        users: { connect: { id: created_by } },
        group_members: { create: { user_id: created_by, role: "owner" } },
      },
      include: groupWithCount,
    }).then(mapGroup);
  }

  update(id: string, data: UpdateGroupInput): Promise<Group> {
    return this.db.groups
      .update({
        where: { id },
        data: { ...data, updated_at: new Date() },
        include: groupWithCount,
      })
      .then(mapGroup);
  }

  delete(id: string): Promise<Group> {
    const remove = async (tx: Prisma.TransactionClient) => {
      await tx.$queryRaw`SELECT id FROM groups WHERE id = ${id}::uuid FOR UPDATE`;
      if (await tx.outings.findFirst({ where: { group_id: id }, select: { id: true } })) {
        throw new ConflictError("A group with outings cannot be deleted");
      }
      const group = await tx.groups.delete({ where: { id } });
      return { ...group, member_count: 0 };
    };
    return "$transaction" in this.db ? this.db.$transaction(remove) : remove(this.db);
  }

  addMember(data: AddGroupMemberInput): Promise<GroupMember> {
    return this.db.group_members.create({ data });
  }

  addInvitedMember(
    groupId: string,
    userId: string,
    callerId?: string,
  ): Promise<{ member: GroupMember; created: boolean }> {
    return addInvitedGroupMember(this.db, groupId, userId, callerId);
  }

  findMember(groupId: string, userId: string): Promise<GroupMember | null> {
    return this.db.group_members.findUnique({
      where: { group_id_user_id: { group_id: groupId, user_id: userId } },
    });
  }

  removeMember(groupId: string, userId: string, callerId: string): Promise<GroupMember> {
    const remove = async (tx: Prisma.TransactionClient) => {
      await tx.$queryRaw`SELECT id FROM groups WHERE id = ${groupId}::uuid FOR UPDATE`;
      const caller = await tx.group_members.findUnique({
        where: { group_id_user_id: { group_id: groupId, user_id: callerId } },
      });
      if (!caller || (callerId !== userId && caller.role !== "owner")) {
        throw new ForbiddenError("Only the group owner can remove another member");
      }
      const where = { group_id_user_id: { group_id: groupId, user_id: userId } };
      const target = await tx.group_members.findUnique({ where });
      if (!target) throw new NotFoundError("Group member");
      if (target.role === "owner" &&
          await tx.group_members.count({ where: { group_id: groupId, role: "owner" } }) <= 1) {
        throw new ForbiddenError("Cannot remove the last owner from the group");
      }
      const user = await tx.users.findUniqueOrThrow({
        where: { id: userId },
        select: { phone: true },
      });
      await tx.group_invitations.updateMany({
        where: { group_id: groupId, invited_phone: user.phone, status: "pending" },
        data: { status: "revoked" },
      });
      return tx.group_members.delete({ where });
    };
    return "$transaction" in this.db ? this.db.$transaction(remove) : remove(this.db);
  }

  listRoster(groupId: string): Promise<GroupRoster> {
    const read = async (tx: Prisma.TransactionClient): Promise<GroupRoster> => {
      const members = await new GroupDatasource(tx).listMembers(groupId);
      const activePhones = new Set(members.map(member => member.phone));
      const invitations = await tx.group_invitations.findMany({
        where: { group_id: groupId },
        select: {
          id: true, invited_phone: true, status: true, created_at: true,
          inviter: { select: { name: true } },
          invitee: { select: { name: true } },
        },
        orderBy: [{ created_at: "desc" }, { id: "asc" }],
      });
      return {
        members,
        pendingMembers: invitations
          .filter(row => row.status === "pending" && !activePhones.has(row.invited_phone))
          .map(row => ({ invitation_id: row.id, phone: row.invited_phone, status: "pending" })),
        invitationHistory: invitations.map(row => ({
          invitation_id: row.id, invited_phone: row.invited_phone,
          invitee_name: row.invitee?.name ?? null, inviter_name: row.inviter.name,
          status: row.status, created_at: row.created_at,
        })),
      };
    };
    // A claim updates both relations atomically. Read both from one snapshot.
    return "$transaction" in this.db
      ? this.db.$transaction(read, { isolationLevel: "RepeatableRead" })
      : read(this.db);
  }

  listMembers(groupId: string): Promise<GroupMemberView[]> {
    return this.db.group_members
      .findMany({
        where: { group_id: groupId },
        include: {
          users: {
            select: { name: true, phone: true, image_url: true },
          },
        },
        orderBy: [{ joined_at: "asc" }],
      })
      .then((rows) =>
        rows.map((row) => ({
          group_id: row.group_id,
          user_id: row.user_id,
          role: row.role,
          joined_at: row.joined_at,
          name: row.users.name,
          phone: row.users.phone,
          image_url: row.users.image_url,
        })),
      );
  }
}
