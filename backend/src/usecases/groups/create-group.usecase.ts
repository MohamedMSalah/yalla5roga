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
    // Creator is the first member (owner). Member count must start at 1.
    await this.groups.addMember({
      group_id: group.id,
      user_id: input.created_by,
      role: "owner",
    });

    const created = await this.groups.findById(group.id);
    if (!created) {
      return {
        ...group,
        member_count: 1,
        my_role: "owner",
      };
    }
    return {
      ...created,
      member_count: created.member_count ?? 1,
      my_role: "owner",
    };
  }
}
