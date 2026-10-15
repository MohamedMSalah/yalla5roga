import type { IGroupRepository } from "../../repositories/groups/i-group.repository.js";
import { GroupRepository } from "../../repositories/groups/group.repository.js";
import type { Group } from "../../types/groups/group.types.js";
import { NotFoundError } from "../../utils/errors.js";

export class DeleteGroupUseCase {
  constructor(
    private readonly groups: IGroupRepository = new GroupRepository(),
  ) {}

  async execute(id: string): Promise<Group> {
    const existing = await this.groups.findById(id);
    if (!existing) throw new NotFoundError("Group");
    return this.groups.delete(id);
  }
}
