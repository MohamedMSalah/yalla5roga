import type { IGroupInvitationRepository } from "../../repositories/groups/i-group-invitation.repository.js";
import { GroupInvitationRepository } from "../../repositories/groups/group-invitation.repository.js";
import { tryNormalizePhoneNumber } from "../../services/phone/normalize-phone.js";
import type { GroupInvitation } from "../../types/groups/group-invitation.types.js";

export class ClaimGroupInvitationsUseCase {
  constructor(
    private readonly invitations: IGroupInvitationRepository = new GroupInvitationRepository(),
  ) {}

  /**
   * `verifiedPhone` must come from the Firebase ID token.
   * A phone typed into the profile is not proof of ownership.
   */
  async execute(input: {
    userId: string;
    verifiedPhone?: string | null;
  }): Promise<GroupInvitation[]> {
    if (!input.verifiedPhone) return [];

    const phone = tryNormalizePhoneNumber(input.verifiedPhone);
    if (!phone) return [];

    return this.invitations.claimForVerifiedPhone(input.userId, phone);
  }
}
