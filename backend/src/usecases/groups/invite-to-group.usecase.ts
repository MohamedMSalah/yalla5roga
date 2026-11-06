import type { IGroupInvitationRepository } from "../../repositories/groups/i-group-invitation.repository.js";
import { GroupInvitationRepository } from "../../repositories/groups/group-invitation.repository.js";
import type { IGroupRepository } from "../../repositories/groups/i-group.repository.js";
import { GroupRepository } from "../../repositories/groups/group.repository.js";
import type { IUserRepository } from "../../repositories/users/i-user.repository.js";
import { UserRepository } from "../../repositories/users/user.repository.js";
import { invitationExpiresAt } from "../../services/groups/invitation-policy.js";
import {
  buildGroupInviteDeepLinks,
  primaryInviteDeepLink,
} from "../../services/notifications/deep-link.js";
import {
  OutboxNotificationPublisher,
  type NotificationPublisher,
} from "../../services/notifications/notification-publisher.js";
import {
  FirebaseVerifiedPhoneLookup,
  type VerifiedPhoneLookup,
} from "../../services/phone/firebase-verified-phone.js";
import { normalizePhoneNumber } from "../../services/phone/normalize-phone.js";
import {
  buildInvitationMessage,
  buildWhatsAppClickToChatUrl,
} from "../../services/whatsapp/invitation-message.js";
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
      deepLink: string;
    }
  | {
      outcome: "already_pending";
      invitation: GroupInvitation;
      whatsappUrl: string;
      deepLink: string;
    };

type BuiltPendingInvite = {
  invitation: GroupInvitation;
  whatsappUrl: string;
  deepLink: string;
  appDeepLink: string;
  messageBody: string;
  inviterName: string;
};

export class InviteToGroupUseCase {
  constructor(
    private readonly groups: IGroupRepository = new GroupRepository(),
    private readonly invitations: IGroupInvitationRepository = new GroupInvitationRepository(),
    private readonly users: IUserRepository = new UserRepository(),
    private readonly verifiedPhones: VerifiedPhoneLookup = new FirebaseVerifiedPhoneLookup(),
    private readonly now: () => Date = () => new Date(),
    private readonly notifications: NotificationPublisher = new OutboxNotificationPublisher(),
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

    const pending = await this.invitations.findPending(input.groupId, phone);
    if (pending) {
      const built = await this.buildPendingInvite(
        group.name,
        input.invitedByUserId,
        pending,
      );
      return {
        outcome: "already_pending",
        invitation: built.invitation,
        whatsappUrl: built.whatsappUrl,
        deepLink: built.deepLink,
      };
    }

    const created = await this.invitations.createPending({
      group_id: input.groupId,
      invited_by_user_id: input.invitedByUserId,
      invited_phone: phone,
      expires_at: invitationExpiresAt(this.now()),
    });

    const built = await this.buildPendingInvite(
      group.name,
      input.invitedByUserId,
      created.invitation,
    );

    if (created.created) {
      await this.notifications.publishGroupInvite({
        invitationId: created.invitation.id,
        groupId: input.groupId,
        groupName: group.name,
        inviterUserId: input.invitedByUserId,
        inviterName: built.inviterName,
        invitedPhone: phone,
        deepLink: built.deepLink,
        appDeepLink: built.appDeepLink,
        body: built.messageBody,
        channel: "whatsapp",
      });
    }

    return {
      outcome: created.created ? "invited" : "already_pending",
      invitation: built.invitation,
      whatsappUrl: built.whatsappUrl,
      deepLink: built.deepLink,
    };
  }

  private async buildPendingInvite(
    groupName: string,
    invitedByUserId: string,
    invitation: GroupInvitation,
  ): Promise<BuiltPendingInvite> {
    const inviterUser = await this.users.findById(invitedByUserId);
    const inviterName = inviterUser?.name?.trim() || "A friend";
    const links = buildGroupInviteDeepLinks({
      invitationId: invitation.id,
      groupId: invitation.group_id,
    });
    const deepLink = primaryInviteDeepLink({
      invitationId: invitation.id,
      groupId: invitation.group_id,
    });
    const messageBody = buildInvitationMessage({
      groupName,
      inviterName,
      deepLink,
    });
    const whatsappUrl = buildWhatsAppClickToChatUrl(
      invitation.invited_phone,
      messageBody,
    );

    return {
      invitation,
      whatsappUrl,
      deepLink,
      appDeepLink: links.app,
      messageBody,
      inviterName,
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
