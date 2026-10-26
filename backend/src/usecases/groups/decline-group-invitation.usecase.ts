import type { IGroupInvitationRepository } from "../../repositories/groups/i-group-invitation.repository.js";
import { GroupInvitationRepository } from "../../repositories/groups/group-invitation.repository.js";
import { tryNormalizePhoneNumber } from "../../services/phone/normalize-phone.js";
import type { GroupInvitation } from "../../types/groups/group-invitation.types.js";
import { ForbiddenError, NotFoundError } from "../../utils/errors.js";

export type DeclineGroupInvitationInput = {
  invitationId: string;
  /** Firebase UID from the verified ID token. */
  userId: string;
  /** `phone_number` claim from the verified ID token; never from the body. */
  verifiedPhone: string | null | undefined;
};

export class DeclineGroupInvitationUseCase {
  constructor(
    private readonly invitations: IGroupInvitationRepository = new GroupInvitationRepository(),
  ) {}

  async execute(input: DeclineGroupInvitationInput): Promise<GroupInvitation> {
    const phone = input.verifiedPhone
      ? tryNormalizePhoneNumber(input.verifiedPhone)
      : null;
    if (!phone) {
      throw new ForbiddenError(
        "A verified phone number is required to decline an invitation",
      );
    }

    const declined = await this.invitations.declineForVerifiedPhone(
      input.invitationId,
      input.userId,
      phone,
    );
    if (declined === 0) {
      // Either the id is unknown, the phone does not match, or it is no longer pending.
      throw new NotFoundError("Pending invitation");
    }

    const invitation = await this.invitations.findById(input.invitationId);
    if (!invitation) throw new NotFoundError("Invitation");
    return invitation;
  }
}
