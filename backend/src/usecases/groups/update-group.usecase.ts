import type { IGroupRepository } from "../../repositories/groups/i-group.repository.js";
import { GroupRepository } from "../../repositories/groups/group.repository.js";
import type { Group, UpdateGroupInput } from "../../types/groups/group.types.js";
import { NotFoundError } from "../../utils/errors.js";

export class UpdateGroupUseCase {
  constructor(
    private readonly groups: IGroupRepository = new GroupRepository(),
  ) {}

  async execute(id: string, data: UpdateGroupInput): Promise<Group> {
    const existing = await this.groups.findById(id);
    if (!existing) throw new NotFoundError("Group");
    return this.groups.update(id, data);
  }
}
