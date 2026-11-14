import { prisma } from "../../config/database.js";
import { chatParticipantIds, mentionedUserIds } from "../chat/chat-mentions.js";
import { listEligibleVoterIds } from "../outings/outing-participants.js";
import { arrivalWindowOpen } from "../outings/arrival-policy.js";
import { notificationPreferences } from "./notification-preferences.js";

export const controlTypes = new Set([
  "chat_updated",
  "chat_deleted",
  "conversation_read",
  "invitation_resolved",
]);

/** Revalidate the current recipient, resource, content and preferences before delivery. */
export async function resolvePush(
  uid: string,
  payload: Record<string, unknown>,
  inboxEventKey?: string | null,
) {
  const type = String(payload.type ?? payload.notificationType ?? "system");
  const control = controlTypes.has(type);
  const user = await prisma.users.findUnique({
    where: { id: uid },
    select: { notification_preferences: true },
  });
  if (!user) return null;
  const prefs = notificationPreferences(user.notification_preferences);
  const messageId =
    typeof payload.messageId === "string" ? payload.messageId : null;
  const inbox = inboxEventKey
    ? await prisma.notifications.findFirst({
        where: { user_id: uid, event_key: inboxEventKey },
      })
    : messageId
      ? await prisma.notifications.findFirst({
          where: {
            user_id: uid,
            event_key: `chat_message:${messageId}:${uid}`,
          },
        })
      : null;
  const metadata = (inbox?.data ?? {}) as Record<string, unknown>;
  const data: Record<string, unknown> = {
    ...metadata,
    ...payload,
    ...(inbox
      ? { notificationId: inbox.id, createdAt: inbox.created_at.toISOString() }
      : {}),
    lockScreenPreview: String(prefs.lockScreenPreview),
    unreadCount: String(
      await prisma.notifications.count({
        where: { user_id: uid, is_read: false },
      }),
    ),
  };
  // Dismissal controls intentionally still reach removed members to erase content.
  if (control && type !== "chat_updated") return data;
  if (!prefs.pushEnabled || (!control && inbox?.is_read)) return null;
  if (data.outingId) {
    const outing = await prisma.outings.findUnique({
      where: { id: String(data.outingId) },
    });
    if (!outing) return null;
    const allowed = type.startsWith("chat")
      ? await chatParticipantIds(outing)
      : await listEligibleVoterIds(outing);
    if (!allowed.includes(uid)) {
      if (
        type !== "outing_invite" ||
        !(await prisma.outing_guests.findFirst({
          where: { outing_id: outing.id, user_id: uid, status: "pending" },
        }))
      )
        return null;
    }
    const reminder =
      type.includes("reminder") ||
      type.includes("approaching") ||
      type === "rsvp_opened";
    if (reminder && ["cancelled", "past"].includes(outing.status)) return null;
    if (type === "voting_started" || type === "voting_deadline_approaching") {
      if (
        outing.status !== "voting" ||
        outing.vote_closed_at ||
        !outing.vote_ends_at ||
        outing.vote_ends_at <= new Date() ||
        (data.deadline && data.deadline !== outing.vote_ends_at.toISOString())
      )
        return null;
    }
    if (
      ["outing_reminder", "venue_reminder", "rsvp_opened"].includes(type) &&
      outing.scheduled_at &&
      outing.scheduled_at <= new Date()
    )
      return null;
    if (data.schedule && data.schedule !== outing.scheduled_at?.toISOString())
      return null;
    if (
      type === "arrival_reminder" &&
      (!arrivalWindowOpen(outing, new Date()) ||
        (await prisma.outing_arrivals.findUnique({
          where: { outing_id_user_id: { outing_id: outing.id, user_id: uid } },
        })))
    )
      return null;
    if (messageId) {
      const message = await prisma.chat_messages.findFirst({
        where: { id: messageId, outing_id: outing.id },
        include: { users: { select: { name: true } } },
      });
      if (!message?.text || inbox?.is_read) return null;
      const mentioned = mentionedUserIds(message.text).includes(uid);
      if (!(mentioned ? prefs.mentions : prefs.chatMessages)) return null;
      Object.assign(data, {
        title: `${message.users.name} — ${outing.title}`,
        body: message.text
          .replace(
            /<@[^|<>]+\|([^<>]*)>/g,
            (_, name: string) => `@${decodeURIComponent(name)}`,
          )
          .slice(0, 500),
        senderName: message.users.name,
        senderId: message.sender_id,
        conversationTitle: outing.title,
        messageSentAt: message.sent_at.toISOString(),
        directMention: String(mentioned),
        mention: String(mentioned && prefs.mentionPriority),
        chatOpen: String(
          !["cancelled", "past"].includes(outing.status) &&
            (!outing.scheduled_at ||
              outing.scheduled_at.getTime() + 7_200_000 > Date.now()),
        ),
      });
    }
    if (type.startsWith("voting") || type.includes("selected")) {
      if (!prefs.voting) return null;
    } else if (reminder) {
      if (!prefs.reminders) return null;
    } else if (type.includes("attendance") || type === "arrival_changed") {
      if (!prefs.attendance) return null;
    } else if (!type.startsWith("chat") && !prefs.outings) return null;
  } else if (data.groupId && type !== "group_invite") {
    if (
      !prefs.groupEvents ||
      !(await prisma.group_members.findUnique({
        where: {
          group_id_user_id: { group_id: String(data.groupId), user_id: uid },
        },
      }))
    )
      return null;
  }
  if (type === "group_invite") {
    if (!data.invitationId) return null;
    const invitation = await prisma.group_invitations.findUnique({
      where: { id: String(data.invitationId) },
    });
    if (
      !invitation ||
      invitation.user_id !== uid ||
      invitation.status !== "pending" ||
      invitation.expires_at <= new Date()
    )
      return null;
  }
  return data;
}
