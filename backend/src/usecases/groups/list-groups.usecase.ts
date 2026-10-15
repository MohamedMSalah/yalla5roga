import type { IGroupRepository } from "../../repositories/groups/i-group.repository.js";
import { GroupRepository } from "../../repositories/groups/group.repository.js";
import type { Group } from "../../types/groups/group.types.js";

export class ListGroupsUseCase {
  constructor(
    private readonly groups: IGroupRepository = new GroupRepository(),
  ) {}

  execute(userId?: string): Promise<Group[]> {
    if (userId) return this.groups.findByUserId(userId);
    return this.groups.findMany();
  }
}
