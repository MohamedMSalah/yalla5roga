import type { IGroupInvitationRepository } from "../../repositories/groups/i-group-invitation.repository.js";
import { GroupInvitationRepository } from "../../repositories/groups/group-invitation.repository.js";
import type { IGroupRepository } from "../../repositories/groups/i-group.repository.js";
import { GroupRepository } from "../../repositories/groups/group.repository.js";
import { publishGroupChange } from "../../realtime/data-changes.js";
import { NotFoundError, ForbiddenError } from "../../utils/errors.js";

export class AcceptGroupInvitationUseCase {
  constructor(
    private readonly invitations: IGroupInvitationRepository = new GroupInvitationRepository(),
    private readonly groups: IGroupRepository = new GroupRepository(),
  ) {}

  /**
   * Accept a pending group invitation.
   *
   * The caller must be the invitee (user_id matches) or the invitation must
   * have no user_id but the caller's phone matches the invited phone.
   *
   * Accepting creates a group_members row (skipping duplicates) and updates
   * the invitation status to `accepted`. The operation is idempotent — calling
   * again on an already-accepted invitation returns the existing record.
   *
   * After acceptance the user gains group access immediately.
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
      // Already accepted / declined — return the persisted state (idempotent)
      return {
        groupId: invitation.group_id,
        invitationId: invitation.id,
        status: invitation.status,
      };
    }

    // Accept the invitation — creates membership and updates status
    const accepted = await this.invitations.accept(input.invitationId, input.userId);
    if (!accepted) {
      throw new NotFoundError("Invitation");
    }

    // Emit real-time event to group members
    await publishGroupChange(invitation.group_id, "membership", [input.userId]);

    return {
      groupId: accepted.group_id,
      invitationId: accepted.id,
      status: accepted.status,
    };
  }
}
