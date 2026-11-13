import type { IGroupRepository } from "../../repositories/groups/i-group.repository.js";
import { GroupRepository } from "../../repositories/groups/group.repository.js";
import { MediaService } from "../../services/media/media.service.js";
import type { CreateGroupInput, Group } from "../../types/groups/group.types.js";
import { ValidationError } from "../../utils/errors.js";

export class CreateGroupUseCase {
  constructor(
    private readonly groups: IGroupRepository = new GroupRepository(),
    private readonly media = new MediaService(),
  ) {}

  async execute(input: CreateGroupInput): Promise<Group> {
    if (!input.name || !input.created_by) {
      throw new ValidationError("name and created_by are required");
    }

    // Verify ownership of a `media://` cover reference before persisting.
    const imageUrl = await this.media.resolveEntityImage({
      uid: input.created_by,
      imageValue: input.image_url,
      purpose: "group",
    });

    const group = await this.groups.create({
      ...input,
      image_url: imageUrl ?? "",
    });
    await this.media.linkReference({
      uid: input.created_by,
      imageValue: imageUrl,
      link: { group_id: group.id },
    });
    return { ...group, my_role: "owner" };
  }
}
