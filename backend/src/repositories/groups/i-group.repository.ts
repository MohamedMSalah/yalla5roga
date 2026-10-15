import type {
  AddGroupMemberInput,
  CreateGroupInput,
  Group,
  GroupMember,
  UpdateGroupInput,
} from "../../types/groups/group.types.js";

export interface IGroupRepository {
  findById(id: string): Promise<Group | null>;
  findMany(): Promise<Group[]>;
  findByUserId(userId: string): Promise<Group[]>;
  create(data: CreateGroupInput): Promise<Group>;
  update(id: string, data: UpdateGroupInput): Promise<Group>;
  delete(id: string): Promise<Group>;
  addMember(data: AddGroupMemberInput): Promise<GroupMember>;
  addInvitedMember(
    groupId: string,
    userId: string,
  ): Promise<{ member: GroupMember; created: boolean }>;
  findMember(groupId: string, userId: string): Promise<GroupMember | null>;
  removeMember(groupId: string, userId: string): Promise<GroupMember>;
  listMembers(groupId: string): Promise<GroupMember[]>;
}
