import type { IGroupRepository } from "../../repositories/groups/i-group.repository.js";
import { GroupRepository } from "../../repositories/groups/group.repository.js";
import type { GroupMemberView } from "../../types/groups/group.types.js";
import { NotFoundError } from "../../utils/errors.js";

export class ListGroupMembersUseCase {
  constructor(
    private readonly groups: IGroupRepository = new GroupRepository(),
  ) {}

  async execute(groupId: string): Promise<GroupMemberView[]> {
    const group = await this.groups.findById(groupId);
    if (!group) throw new NotFoundError("Group");
    return this.groups.listMembers(groupId);
  }
}
