import type { IGroupRepository } from "../../repositories/groups/i-group.repository.js";
import { GroupRepository } from "../../repositories/groups/group.repository.js";
import { assertGroupMember, assertGroupOwner } from "../../services/groups/group-access.js";
import type { GroupMember } from "../../types/groups/group.types.js";
import { ForbiddenError, NotFoundError } from "../../utils/errors.js";

export class RemoveGroupMemberUseCase {
  constructor(
    private readonly groups: IGroupRepository = new GroupRepository(),
  ) {}

  async execute(
    groupId: string,
    callerUid: string,
    userId: string,
  ): Promise<GroupMember> {
    if (callerUid === userId) {
      await assertGroupMember(this.groups, groupId, callerUid);
    } else {
      await assertGroupOwner(this.groups, groupId, callerUid);
    }

    const target = await this.groups.findMember(groupId, userId);
    if (!target) throw new NotFoundError("Group member");

    // Forbid removing the last remaining owner (including self-remove).
    if (target.role === "owner") {
      const members = await this.groups.listMembers(groupId);
      const ownerCount = members.filter((m) => m.role === "owner").length;
      if (ownerCount <= 1) {
        throw new ForbiddenError(
          "Cannot remove the last owner from the group",
        );
      }
    }

    return this.groups.removeMember(groupId, userId, callerUid);
  }
}
