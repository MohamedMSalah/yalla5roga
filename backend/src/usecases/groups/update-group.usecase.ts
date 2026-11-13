import type { IGroupRepository } from "../../repositories/groups/i-group.repository.js";
import { GroupRepository } from "../../repositories/groups/group.repository.js";
import { assertGroupOwner } from "../../services/groups/group-access.js";
import { MediaService } from "../../services/media/media.service.js";
import type { Group, UpdateGroupInput } from "../../types/groups/group.types.js";

export class UpdateGroupUseCase {
  constructor(
    private readonly groups: IGroupRepository = new GroupRepository(),
    private readonly media = new MediaService(),
  ) {}

  async execute(
    id: string,
    callerUid: string,
    data: UpdateGroupInput,
  ): Promise<Group> {
    await assertGroupOwner(this.groups, id, callerUid);

    const patch: UpdateGroupInput = { ...data };
    if (data.image_url !== undefined) {
      patch.image_url = await this.media.resolveEntityImage({
        uid: callerUid,
        imageValue: data.image_url,
        purpose: "group",
        link: { group_id: id },
      }) ?? undefined;
    }
    return this.groups.update(id, patch);
  }
}
