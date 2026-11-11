import type { IGroupRepository } from "../../repositories/groups/i-group.repository.js";
import { GroupRepository } from "../../repositories/groups/group.repository.js";
import type { Group } from "../../types/groups/group.types.js";
import { ForbiddenError, NotFoundError } from "../../utils/errors.js";

export class GetGroupUseCase {
  constructor(
    private readonly groups: IGroupRepository = new GroupRepository(),
  ) {}

  async execute(id: string, callerUid: string): Promise<Group> {
    const group = await this.groups.findById(id);
    if (!group) throw new NotFoundError("Group");
    const membership = await this.groups.findMember(id, callerUid);
    if (!membership) throw new ForbiddenError("Only group members can access this group");
    return { ...group, my_role: membership.role };
  }
}
