import { prisma } from "../../config/database.js";
import { addInvitedGroupMember } from "./group-membership.js";
import type {
  AddGroupMemberInput,
  CreateGroupInput,
  Group,
  GroupMember,
  UpdateGroupInput,
} from "../../types/groups/group.types.js";

export class GroupDatasource {
  findById(id: string): Promise<Group | null> {
    return prisma.groups.findUnique({ where: { id } });
  }

  findMany(): Promise<Group[]> {
    return prisma.groups.findMany({ orderBy: { created_at: "desc" } });
  }

  findByUserId(userId: string): Promise<Group[]> {
    return prisma.groups.findMany({
      where: { group_members: { some: { user_id: userId } } },
      orderBy: { updated_at: "desc" },
    });
  }

  create(data: CreateGroupInput): Promise<Group> {
    return prisma.groups.create({ data });
  }

  update(id: string, data: UpdateGroupInput): Promise<Group> {
    return prisma.groups.update({
      where: { id },
      data: { ...data, updated_at: new Date() },
    });
  }

  delete(id: string): Promise<Group> {
    return prisma.groups.delete({ where: { id } });
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

  listMembers(groupId: string): Promise<GroupMember[]> {
    return prisma.group_members.findMany({ where: { group_id: groupId } });
  }
}
