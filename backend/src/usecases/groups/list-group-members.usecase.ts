import type { IGroupRepository } from "../../repositories/groups/i-group.repository.js";
import { GroupRepository } from "../../repositories/groups/group.repository.js";
import type { GroupRoster } from "../../types/groups/group.types.js";
import { assertGroupMember } from "../../services/groups/group-access.js";

export class ListGroupMembersUseCase {
  constructor(
    private readonly groups: IGroupRepository = new GroupRepository(),
  ) {}

  async execute(groupId: string, callerUid: string): Promise<GroupRoster> {
    await assertGroupMember(this.groups, groupId, callerUid);
    return this.groups.listRoster(groupId);
  }
}
