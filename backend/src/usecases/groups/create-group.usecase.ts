import type { IGroupRepository } from "../../repositories/groups/i-group.repository.js";
import { GroupRepository } from "../../repositories/groups/group.repository.js";
import type { CreateGroupInput, Group } from "../../types/groups/group.types.js";
import { ValidationError } from "../../utils/errors.js";

export class CreateGroupUseCase {
  constructor(
    private readonly groups: IGroupRepository = new GroupRepository(),
  ) {}

  async execute(input: CreateGroupInput): Promise<Group> {
    if (!input.name || !input.created_by) {
      throw new ValidationError("name and created_by are required");
    }

    const group = await this.groups.create({
      ...input,
      image_url: input.image_url ?? "",
    });
    await this.groups.addMember({
      group_id: group.id,
      user_id: input.created_by,
      role: "owner",
    });

    return group;
  }
}
