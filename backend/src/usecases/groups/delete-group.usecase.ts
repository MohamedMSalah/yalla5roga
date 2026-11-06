import type { IGroupRepository } from "../../repositories/groups/i-group.repository.js";
import { GroupRepository } from "../../repositories/groups/group.repository.js";
import { assertGroupOwner } from "../../services/groups/group-access.js";
import type { Group } from "../../types/groups/group.types.js";

export class DeleteGroupUseCase {
  constructor(
    private readonly groups: IGroupRepository = new GroupRepository(),
  ) {}

  async execute(id: string, callerUid: string): Promise<Group> {
    await assertGroupOwner(this.groups, id, callerUid);
    return this.groups.delete(id);
  }
}
