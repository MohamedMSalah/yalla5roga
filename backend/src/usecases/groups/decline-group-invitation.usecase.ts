import type { IGroupInvitationRepository } from "../../repositories/groups/i-group-invitation.repository.js";
import { GroupInvitationRepository } from "../../repositories/groups/group-invitation.repository.js";
import { publishGroupChange } from "../../realtime/data-changes.js";
import { NotFoundError, ForbiddenError } from "../../utils/errors.js";

export class DeclineGroupInvitationUseCase {
  constructor(
    private readonly invitations: IGroupInvitationRepository = new GroupInvitationRepository(),
  ) {}

  /**
   * Decline a pending group invitation.
   *
   * The caller must be the invitee (user_id matches) or the invitation must
   * have no user_id but the caller's phone matches the invited phone.
   *
   * Declining preserves the invitation record with status `declined` but
   * does NOT create a group membership. The invitee is removed from visible
   * group members after this action.
   */
  async execute(input: {
    invitationId: string;
    userId: string;
    userPhone?: string | null;
  }): Promise<{ groupId: string; invitationId: string; status: string }> {
    const invitation = await this.invitations.findById(input.invitationId);
    if (!invitation) {
      throw new NotFoundError("Invitation");
    }

    // Verify the caller is the invitee
    const isInvitee = invitation.user_id === input.userId ||
      (invitation.user_id === null && invitation.invited_phone === input.userPhone);
    if (!isInvitee) {
      throw new ForbiddenError("This invitation is not for you");
    }

    if (invitation.status !== "pending") {
      // Already declined / accepted — return the persisted state (idempotent)
      return {
        groupId: invitation.group_id,
        invitationId: invitation.id,
        status: invitation.status,
      };
    }

    const declined = await this.invitations.decline(input.invitationId, input.userId);
    if (!declined) {
      throw new NotFoundError("Invitation");
    }

    // Emit real-time event so the inviter sees the invitee disappear from pending
    await publishGroupChange(invitation.group_id, "group");

    return {
      groupId: declined.group_id,
      invitationId: declined.id,
      status: declined.status,
    };
  }
}
