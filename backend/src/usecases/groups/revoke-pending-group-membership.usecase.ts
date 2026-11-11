import { GroupInvitationRepository } from "../../repositories/groups/group-invitation.repository.js";
import { GroupRepository } from "../../repositories/groups/group.repository.js";
import { assertGroupOwner } from "../../services/groups/group-access.js";
import { NotFoundError } from "../../utils/errors.js";

export class RevokePendingGroupMembershipUseCase {
  async execute(input: { invitationId: string; userId: string; groupId: string }) {
    await assertGroupOwner(new GroupRepository(), input.groupId, input.userId);
    const revoked = await new GroupInvitationRepository().revokePending(
      input.groupId,
      input.invitationId,
    );
    if (!revoked) throw new NotFoundError("Pending group membership");
    return revoked;
  }
}
