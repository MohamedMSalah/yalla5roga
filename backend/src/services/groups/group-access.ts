import type { IGroupRepository } from "../../repositories/groups/i-group.repository.js";
import { ForbiddenError, NotFoundError } from "../../utils/errors.js";

/**
 * Requires the caller to hold `owner` role in `group_members`.
 * Used for group update/delete and direct add/remove member.
 */
export async function assertGroupOwner(
  groups: IGroupRepository,
  groupId: string,
  callerUid: string,
): Promise<void> {
  const group = await groups.findById(groupId);
  if (!group) throw new NotFoundError("Group");

  const membership = await groups.findMember(groupId, callerUid);
  if (!membership || membership.role !== "owner") {
    throw new ForbiddenError("Only the group owner can perform this action");
  }
}
