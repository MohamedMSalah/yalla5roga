import type { IGroupRepository } from "../../repositories/groups/i-group.repository.js";
import { GroupRepository } from "../../repositories/groups/group.repository.js";
import { assertGroupOwner } from "../../services/groups/group-access.js";
import type { Group, UpdateGroupInput } from "../../types/groups/group.types.js";

export class UpdateGroupUseCase {
  constructor(
    private readonly groups: IGroupRepository = new GroupRepository(),
  ) {}

  async execute(
    id: string,
    callerUid: string,
    data: UpdateGroupInput,
  ): Promise<Group> {
    await assertGroupOwner(this.groups, id, callerUid);
    return this.groups.update(id, data);
  }
}
