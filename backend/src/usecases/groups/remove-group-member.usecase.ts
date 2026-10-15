import type { IGroupRepository } from "../../repositories/groups/i-group.repository.js";
import { GroupRepository } from "../../repositories/groups/group.repository.js";
import type { GroupMember } from "../../types/groups/group.types.js";
import { NotFoundError } from "../../utils/errors.js";

export class RemoveGroupMemberUseCase {
  constructor(
    private readonly groups: IGroupRepository = new GroupRepository(),
  ) {}

  async execute(groupId: string, userId: string): Promise<GroupMember> {
    const group = await this.groups.findById(groupId);
    if (!group) throw new NotFoundError("Group");
    return this.groups.removeMember(groupId, userId);
  }
}
