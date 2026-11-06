import type {
  notification_event_type,
  notification_type,
} from "@prisma/client";
import { prisma } from "../../config/database.js";
import type { Outing } from "../../types/outings/outing.types.js";
import { listParticipantIds } from "../outings/outing-participants.js";

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

  for (const userId of recipients) {
    const perUserKey = `${input.eventKey}:${userId}`;
    try {
      await prisma.notifications.create({
        data: {
          user_id: userId,
          body: input.body.slice(0, 500),
          type: input.type,
          outing_id: input.outing.id,
          group_id: input.outing.group_id,
          action_required: input.actionRequired ?? false,
          event_key: perUserKey,
        },
      });
    } catch (error: unknown) {
      // Unique violation on event_key → already notified (idempotent retry).
      if (
        typeof error === "object" &&
        error &&
        "code" in error &&
        (error as { code?: string }).code === "P2002"
      ) {
        continue;
      }
      throw error;
    }

    try {
      await prisma.notification_events.create({
        data: {
          type: input.eventType,
          channel: "push",
          recipient_user_id: userId,
          outing_id: input.outing.id,
          group_id: input.outing.group_id,
          event_key: `outbox:${perUserKey}`,
          payload: {
            body: input.body,
            outing_id: input.outing.id,
            notification_type: input.type,
          },
        },
      });
    } catch (error: unknown) {
      if (
        typeof error === "object" &&
        error &&
        "code" in error &&
        (error as { code?: string }).code === "P2002"
      ) {
        continue;
      }
      throw error;
    }
  }
}
