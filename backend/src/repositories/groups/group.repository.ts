import { GroupDatasource } from "../../datasources/groups/group.datasource.js";
import type {
  AddGroupMemberInput,
  CreateGroupInput,
  Group,
  GroupMember,
  UpdateGroupInput,
} from "../../types/groups/group.types.js";
import type { IGroupRepository } from "./i-group.repository.js";

export class GroupRepository implements IGroupRepository {
  constructor(private readonly datasource = new GroupDatasource()) {}

  findById(id: string): Promise<Group | null> {
    return this.datasource.findById(id);
  }

  findMany(): Promise<Group[]> {
    return this.datasource.findMany();
  }

  findByUserId(userId: string): Promise<Group[]> {
    return this.datasource.findByUserId(userId);
  }

  create(data: CreateGroupInput): Promise<Group> {
    return this.datasource.create(data);
  }

  update(id: string, data: UpdateGroupInput): Promise<Group> {
    return this.datasource.update(id, data);
  }

  delete(id: string): Promise<Group> {
    return this.datasource.delete(id);
  }

  addMember(data: AddGroupMemberInput): Promise<GroupMember> {
    return this.datasource.addMember(data);
  }

  addInvitedMember(
    groupId: string,
    userId: string,
  ): Promise<{ member: GroupMember; created: boolean }> {
    return this.datasource.addInvitedMember(groupId, userId);
  }

  findMember(groupId: string, userId: string): Promise<GroupMember | null> {
    return this.datasource.findMember(groupId, userId);
  }

  removeMember(groupId: string, userId: string): Promise<GroupMember> {
    return this.datasource.removeMember(groupId, userId);
  }

  listMembers(groupId: string): Promise<GroupMember[]> {
    return this.datasource.listMembers(groupId);
  }
}
