import type { IGroupInvitationRepository } from "../../repositories/groups/i-group-invitation.repository.js";
import { GroupInvitationRepository } from "../../repositories/groups/group-invitation.repository.js";
import type { IGroupRepository } from "../../repositories/groups/i-group.repository.js";
import { GroupRepository } from "../../repositories/groups/group.repository.js";
import type { IUserRepository } from "../../repositories/users/i-user.repository.js";
import { UserRepository } from "../../repositories/users/user.repository.js";
import { invitationExpiresAt } from "../../services/groups/invitation-policy.js";
import {
  FirebaseVerifiedPhoneLookup,
  type VerifiedPhoneLookup,
} from "../../services/phone/firebase-verified-phone.js";
import { normalizePhoneNumber } from "../../services/phone/normalize-phone.js";
import { buildWhatsAppClickToChatUrl } from "../../services/whatsapp/invitation-message.js";
import type { GroupInvitation } from "../../types/groups/group-invitation.types.js";
import type { GroupMember } from "../../types/groups/group.types.js";
import { ForbiddenError, NotFoundError } from "../../utils/errors.js";

export type InviteToGroupInput = {
  groupId: string;
  phoneNumber: string;
  invitedByUserId: string;
};

export type InviteToGroupResult =
  | { outcome: "member_added"; member: GroupMember }
  | { outcome: "already_member"; member: GroupMember }
  | {
      outcome: "invited";
      invitation: GroupInvitation;
      whatsappUrl: string;
    }
  | {
      outcome: "already_pending";
      invitation: GroupInvitation;
      whatsappUrl: string;
    };

export class InviteToGroupUseCase {
  constructor(
    private readonly groups: IGroupRepository = new GroupRepository(),
    private readonly invitations: IGroupInvitationRepository = new GroupInvitationRepository(),
    private readonly users: IUserRepository = new UserRepository(),
    private readonly verifiedPhones: VerifiedPhoneLookup = new FirebaseVerifiedPhoneLookup(),
    private readonly now: () => Date = () => new Date(),
  ) {}

  async execute(input: InviteToGroupInput): Promise<InviteToGroupResult> {
    const phone = normalizePhoneNumber(input.phoneNumber);

    const group = await this.groups.findById(input.groupId);
    if (!group) throw new NotFoundError("Group");

    const inviter = await this.groups.findMember(
      input.groupId,
      input.invitedByUserId,
    );
    if (!inviter) {
      throw new ForbiddenError("Only group members can invite");
    }

    const verifiedUserId =
      await this.verifiedPhones.findUserIdByVerifiedPhone(phone);
    if (verifiedUserId) {
      const localUser = await this.users.findById(verifiedUserId);
      if (localUser?.id === verifiedUserId) {
        return this.addExistingMember(input.groupId, verifiedUserId);
      }
    }

    const whatsappUrl = buildWhatsAppClickToChatUrl(phone);
    const pending = await this.invitations.findPending(input.groupId, phone);
    if (pending) {
      return { outcome: "already_pending", invitation: pending, whatsappUrl };
    }

    const created = await this.invitations.createPending({
      group_id: input.groupId,
      invited_by_user_id: input.invitedByUserId,
      invited_phone: phone,
      expires_at: invitationExpiresAt(this.now()),
    });

    return {
      outcome: created.created ? "invited" : "already_pending",
      invitation: created.invitation,
      whatsappUrl,
    };
  }

  private async addExistingMember(
    groupId: string,
    userId: string,
  ): Promise<InviteToGroupResult> {
    const existing = await this.groups.findMember(groupId, userId);
    if (existing) return { outcome: "already_member", member: existing };

    const { member } = await this.groups.addInvitedMember(groupId, userId);
    return { outcome: "member_added", member };
  }
}
