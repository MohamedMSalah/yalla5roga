import type { IGroupInvitationRepository } from "../../repositories/groups/i-group-invitation.repository.js";
import { GroupInvitationRepository } from "../../repositories/groups/group-invitation.repository.js";
import type { IGroupRepository } from "../../repositories/groups/i-group.repository.js";
import { GroupRepository } from "../../repositories/groups/group.repository.js";
import type { IUserRepository } from "../../repositories/users/i-user.repository.js";
import { UserRepository } from "../../repositories/users/user.repository.js";
import { invitationExpiresAt } from "../../services/groups/invitation-policy.js";
import { getNotificationConfig, hasAutomaticWhatsApp } from "../../config/notifications.js";
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
} from "../../services/whatsapp/invitation-message.js";
import type { GroupInvitation } from "../../types/groups/group-invitation.types.js";
import type { GroupMember } from "../../types/groups/group.types.js";
import { ForbiddenError, NotFoundError } from "../../utils/errors.js";
import { emitDataChange, publishGroupChange } from "../../realtime/data-changes.js";

export type InviteToGroupInput = {
  groupId: string;
  phoneNumber: string;
  whatsappOptIn?: boolean;
  invitedByUserId: string;
};

export type InviteToGroupResult =
  | { outcome: "member_added"; member: GroupMember }
  | { outcome: "already_member"; member: GroupMember }
  | {
      outcome: "invited";
      invitation: GroupInvitation;
      whatsappUrl: string | null;
      notificationQueued: boolean;
      deepLink: string;
    }
  | {
      outcome: "already_pending";
      invitation: GroupInvitation;
      whatsappUrl: string | null;
      notificationQueued: boolean;
      deepLink: string;
    };

type BuiltPendingInvite = {
  invitation: GroupInvitation;
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
    private readonly automaticWhatsApp = hasAutomaticWhatsApp,
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

    const verifiedId = await this.verifiedPhones.findUserIdByVerifiedPhone(phone);
    if (verifiedId && (await this.users.findById(verifiedId))?.phone === phone) {
      const member = await this.groups.findMember(input.groupId, verifiedId);
      if (member) return { outcome: "already_member", member };
    }

    const now = this.now();
    const pending = await this.invitations.findPending(input.groupId, phone, now);
    const result = pending
      ? { created: false, invitation: pending }
      : await this.invitations.createPending({
          group_id: input.groupId,
          invited_by_user_id: input.invitedByUserId,
          invited_phone: phone,
          expires_at: invitationExpiresAt(now),
        }, now);

    // Registration can finish between the first Firebase lookup and the
    // pending insert. Recheck after persistence and claim only live rows.
    const registeredId = await this.verifiedPhones.findUserIdByVerifiedPhone(phone);
    if (registeredId && (await this.users.findById(registeredId))?.phone === phone) {
      const claimed = await this.invitations.claimForVerifiedPhone(registeredId, phone);
      if (claimed.length) emitDataChange({ kind: "inbox" }, [registeredId]);
      // This race-repair claim can link other groups too. The controller
      // publishes this group; publish every other committed link here.
      await Promise.all([...new Set(claimed.map(row => row.group_id))]
        .filter(id => id !== input.groupId)
        .map(id => publishGroupChange(id, "group", [registeredId])));
      const member = await this.groups.findMember(input.groupId, registeredId);
      if (member) {
        return {
          outcome: "already_member",
          member,
        };
      }
    }

    const built = await this.buildPendingInvite(
      group.name,
      result.invitation.invited_by_user_id,
      result.invitation,
    );
    let notificationQueued = input.whatsappOptIn === true && this.automaticWhatsApp();
    if (notificationQueued) {
      await this.notifications.publishGroupInvite({
        whatsappOptIn: true,
        invitationId: result.invitation.id,
        groupId: input.groupId,
        groupName: group.name,
        inviterUserId: result.invitation.invited_by_user_id,
        inviterName: built.inviterName,
        invitedPhone: phone,
        deepLink: built.deepLink,
        appDeepLink: built.appDeepLink,
        body: built.messageBody,
        channel: "whatsapp",
      }).catch((error: unknown) => {
        notificationQueued = false;
        console.error("[group-invitation] enqueue failed", error);
      });
    }

    return {
      outcome: result.created ? "invited" : "already_pending",
      invitation: result.invitation,
      whatsappUrl: null,
      notificationQueued,
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
    const downloadUrl = getNotificationConfig().deepLinkBaseUrl;
    const messageBody = buildInvitationMessage({
      groupName,
      inviterName,
      deepLink,
      downloadUrl,
    });
    return {
      invitation,
      deepLink,
      appDeepLink: links.app,
      messageBody,
      inviterName,
    };
  }

}
