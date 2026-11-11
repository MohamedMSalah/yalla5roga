import type {
  notification_event_type,
  notification_type,
} from "@prisma/client";
import { prisma } from "../../config/database.js";
import type { Outing } from "../../types/outings/outing.types.js";
import { listParticipantIds } from "../outings/outing-participants.js";
import { emitDataChange } from "../../realtime/data-changes.js";

type NotifyInput = {
  outing: Outing;
  type: notification_type;
  eventType: notification_event_type;
  body: string;
  eventKey: string;
  actionRequired?: boolean;
  /** When set, only these users receive the notification. */
  userIds?: string[];
  excludeUserId?: string;
};

/**
 * Creates idempotent in-app notification rows for outing participants.
 * Uses notifications.event_key uniqueness to prevent duplicate fan-out on retries.
 */
export async function notifyOutingParticipants(
  input: NotifyInput,
): Promise<void> {
  const recipients = new Set(
    input.userIds ?? (await listParticipantIds(input.outing)),
  );
  if (input.excludeUserId) recipients.delete(input.excludeUserId);

  if (recipients.size === 0) return;

  const rows = [...recipients].map(userId => ({
    user_id: userId,
    body: input.body.slice(0, 500),
    type: input.type,
    outing_id: input.outing.id,
    group_id: input.outing.group_id,
    action_required: input.actionRequired ?? false,
    event_key: `${input.eventKey}:${userId}`,
  }));
  await prisma.$transaction([
    prisma.notifications.createMany({ data: rows, skipDuplicates: true }),
    prisma.notification_events.createMany({
      data: rows.map(row => ({
        type: input.eventType,
        channel: "push",
        recipient_user_id: row.user_id,
        outing_id: row.outing_id,
        group_id: row.group_id,
        event_key: `outbox:${row.event_key}`,
        payload: {
          body: input.body,
          outing_id: row.outing_id,
          notification_type: row.type,
        },
      })),
      skipDuplicates: true,
    }),
  ]);
  emitDataChange({ kind: "inbox" }, [...recipients]);
}
