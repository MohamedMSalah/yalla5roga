import type { Prisma, group_invitations } from "@prisma/client";
import {
  persistNotifications,
  persistNotificationControl,
} from "./persist-notification.js";

export async function persistGroupInvitation(
  tx: Prisma.TransactionClient,
  invitation: group_invitations,
) {
  if (
    !invitation.user_id ||
    invitation.status !== "pending" ||
    invitation.expires_at <= new Date()
  )
    return;
  const group = await tx.groups.findUniqueOrThrow({
    where: { id: invitation.group_id },
  });
  const inviter = await tx.users.findUniqueOrThrow({
    where: { id: invitation.invited_by_user_id },
  });
  await persistNotifications(tx, {
    recipients: [invitation.user_id],
    eventKey: `group_invite:${invitation.id}`,
    eventType: "group_invite",
    type: "invitation",
    title: "Group Invitation",
    body: `${inviter.name} invited you to join ${group.name}.`,
    groupId: group.id,
    invitationId: invitation.id,
    actionRequired: true,
  });
}

export async function persistInvitationDecision(
  tx: Prisma.TransactionClient,
  invitation: group_invitations,
) {
  if (!invitation.user_id) return;
  await tx.notifications.updateMany({
    where: {
      user_id: invitation.user_id,
      event_key: `group_invite:${invitation.id}:${invitation.user_id}`,
    },
    data: { is_read: true, action_required: false },
  });
  await persistNotificationControl(tx, {
    recipients: [invitation.user_id],
    invitationId: invitation.id,
    type: "invitation_resolved",
    eventKey: `invitation_resolved:${invitation.id}`,
  });
  if (invitation.status !== "accepted") return;
  const group = await tx.groups.findUniqueOrThrow({
    where: { id: invitation.group_id },
  });
  const user = await tx.users.findUniqueOrThrow({
    where: { id: invitation.user_id },
  });
  const members = await tx.group_members.findMany({
    where: { group_id: group.id },
  });
  await persistNotifications(tx, {
    recipients: [user.id],
    eventKey: `membership_activated:${invitation.id}`,
    eventType: "membership_activated",
    type: "group",
    title: group.name,
    body: `You joined ${group.name}.`,
    groupId: group.id,
  });
  await persistNotifications(tx, {
    recipients: members.map((m) => m.user_id).filter((id) => id !== user.id),
    eventKey: `member_joined:${invitation.id}`,
    eventType: "member_joined",
    type: "group",
    title: group.name,
    body: `${user.name} joined ${group.name}.`,
    groupId: group.id,
  });
}
