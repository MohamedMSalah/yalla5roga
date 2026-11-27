import { createHash } from "node:crypto";
import type {
  Prisma,
  notification_event_type,
  notification_type,
} from "@prisma/client";

export type NotificationInput = {
  recipients: string[];
  eventKey: string;
  eventType: notification_event_type;
  type: notification_type;
  title: string;
  body: string;
  outingId?: string | null;
  groupId?: string | null;
  invitationId?: string | null;
  messageId?: string;
  actionRequired?: boolean;
  createdAt?: Date;
  data?: Record<string, string>;
};

// Stable across process restarts, producer retries, REST and FCM delivery.
function stableId(key: string): string {
  const hex = createHash("sha256").update(key).digest("hex");
  return `${hex.slice(0, 8)}-${hex.slice(8, 12)}-5${hex.slice(13, 16)}-a${hex.slice(17, 20)}-${hex.slice(20, 32)}`;
}

/** Called inside the business transaction. Never sends to Firebase here. */
export async function persistNotifications(
  tx: Prisma.TransactionClient,
  input: NotificationInput,
) {
  const createdAt = (input.createdAt ?? new Date()).toISOString();
  const rows = [...new Set(input.recipients)].map((uid) => {
    const original = `${input.eventKey}:${uid}`;
    const key =
      original.length <= 180
        ? original
        : `${input.eventKey.split(":").slice(0, 2).join(":")}:${createHash("sha256").update(original).digest("hex")}`;
    const data = {
      ...input.data,
      notificationId: stableId(`inbox:${key}`),
      eventId: stableId(`outbox:${key}`),
      notificationType: input.eventType,
      type: input.eventType,
      recipientUserId: uid,
      actionType: "open",
      createdAt,
      title: input.title,
      body: input.body.slice(0, 500),
      ...(input.groupId ? { groupId: input.groupId } : {}),
      ...(input.outingId ? { outingId: input.outingId } : {}),
      ...(input.invitationId ? { invitationId: input.invitationId } : {}),
      ...(input.messageId ? { messageId: input.messageId } : {}),
    };
    return { uid, key, data };
  });
  if (!rows.length) return;
  await tx.notifications.createMany({
    data: rows.map(({ uid, key, data }) => ({
      id: data.notificationId,
      user_id: uid,
      event_key: key,
      type: input.type,
      body: data.body,
      outing_id: input.outingId,
      group_id: input.groupId,
      action_required: input.actionRequired ?? false,
      created_at: input.createdAt,
      data,
    })),
    skipDuplicates: true,
  });
  await tx.notification_events.createMany({
    data: rows.map(({ uid, key, data }) => ({
      id: data.eventId,
      event_key: `outbox:${key}`,
      type: input.eventType,
      channel: "push",
      recipient_user_id: uid,
      group_id: input.groupId,
      outing_id: input.outingId,
      invitation_id: input.invitationId,
      created_at: input.createdAt,
      payload: data,
    })),
    skipDuplicates: true,
  });
}

/** Silent control events update/dismiss existing OS notifications on all devices. */
export async function persistNotificationControl(
  tx: Prisma.TransactionClient,
  input: {
    recipients: string[];
    eventKey: string;
    type:
      | "chat_updated"
      | "chat_deleted"
      | "conversation_read"
      | "invitation_resolved";
    outingId?: string;
    invitationId?: string;
    messageId?: string;
    data?: Record<string, string>;
  },
) {
  await tx.notification_events.createMany({
    data: [...new Set(input.recipients)].map((uid) => ({
      type: input.type,
      channel: "push",
      recipient_user_id: uid,
      outing_id: input.outingId,
      invitation_id: input.invitationId,
      event_key: `${input.eventKey}:${uid}`,
      payload: {
        ...input.data,
        type: input.type,
        notificationType: input.type,
        recipientUserId: uid,
        actionType: "update",
        createdAt: new Date().toISOString(),
        ...(input.outingId ? { outingId: input.outingId } : {}),
        ...(input.invitationId ? { invitationId: input.invitationId } : {}),
        ...(input.messageId ? { messageId: input.messageId } : {}),
      },
    })),
    skipDuplicates: true,
  });
}
