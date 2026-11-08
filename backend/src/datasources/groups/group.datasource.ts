import type { group_role } from "@prisma/client";
import { prisma } from "../../config/database.js";
import { addInvitedGroupMember } from "./group-membership.js";
import type {
  AddGroupMemberInput,
  CreateGroupInput,
  Group,
  GroupMember,
  GroupMemberView,
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
  findById(id: string): Promise<Group | null> {
    return prisma.groups
      .findUnique({
        where: { id },
        include: groupWithCount,
      })
      .then((row) => (row ? mapGroup(row) : null));
  }

  findMany(): Promise<Group[]> {
    return prisma.groups
      .findMany({
        orderBy: { created_at: "desc" },
        include: groupWithCount,
      })
      .then((rows) => rows.map(mapGroup));
  }

  findByUserId(userId: string): Promise<Group[]> {
    return prisma.groups
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
    return prisma.groups.create({ data }).then((group) => ({
      ...group,
      member_count: 0,
    }));
  }

  update(id: string, data: UpdateGroupInput): Promise<Group> {
    return prisma.groups
      .update({
        where: { id },
        data: { ...data, updated_at: new Date() },
        include: groupWithCount,
      })
      .then(mapGroup);
  }

  delete(id: string): Promise<Group> {
    return prisma.groups.delete({ where: { id } }).then((group) => ({
      ...group,
      member_count: 0,
    }));
  }

  addMember(data: AddGroupMemberInput): Promise<GroupMember> {
    return prisma.group_members.create({ data });
  }

  addInvitedMember(
    groupId: string,
    userId: string,
  ): Promise<{ member: GroupMember; created: boolean }> {
    return addInvitedGroupMember(prisma, groupId, userId);
  }

  findMember(groupId: string, userId: string): Promise<GroupMember | null> {
    return prisma.group_members.findUnique({
      where: { group_id_user_id: { group_id: groupId, user_id: userId } },
    });
  }

  removeMember(groupId: string, userId: string): Promise<GroupMember> {
    return prisma.group_members.delete({
      where: { group_id_user_id: { group_id: groupId, user_id: userId } },
    });
  }

  listMembers(groupId: string): Promise<GroupMemberView[]> {
    return prisma.group_members
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
