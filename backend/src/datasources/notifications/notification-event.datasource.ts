import type { Prisma } from "@prisma/client";
import { prisma } from "../../config/database.js";
import { getNotificationConfig } from "../../config/notifications.js";
import type {
  EnqueueGroupInviteInput,
  GroupInvitePayload,
  NotificationDeliveryLog,
  NotificationEvent,
} from "../../types/notifications/notification-event.types.js";

function asInvitePayload(value: Prisma.JsonValue): GroupInvitePayload {
  return value as unknown as GroupInvitePayload;
}

export class NotificationEventDatasource {
  constructor(
    private readonly db = prisma,
    private readonly config = getNotificationConfig(),
  ) {}

  async enqueueGroupInvite(
    input: EnqueueGroupInviteInput,
  ): Promise<NotificationEvent> {
    const payload: GroupInvitePayload = {
      invitationId: input.invitationId,
      whatsappOptIn: input.whatsappOptIn,
      groupId: input.groupId,
      groupName: input.groupName,
      inviterName: input.inviterName,
      invitedPhone: input.invitedPhone,
      deepLink: input.deepLink,
      appDeepLink: input.appDeepLink,
      body: input.body,
    };

    const eventKey = `group_invite:${input.invitationId}`;
    return this.db.notification_events.upsert({
      where: { event_key: eventKey },
      update: {},
      create: {
        event_key: eventKey,
        type: "group_invite",
        channel: input.channel ?? "whatsapp",
        status: "pending",
        recipient_phone: input.invitedPhone,
        recipient_user_id: null,
        group_id: input.groupId,
        invitation_id: input.invitationId,
        payload,
        max_attempts: input.maxAttempts ?? this.config.worker.maxAttempts,
        next_attempt_at: new Date(),
      },
    });
  }

  /**
   * Atomically claims due pending/failed events for the worker.
   * Uses SKIP LOCKED so multiple workers can scale horizontally.
   */
  async claimDue(batchSize: number, now = new Date()): Promise<NotificationEvent[]> {
    return this.db.$transaction(async (tx) => {
      const due = await tx.$queryRaw<Array<{ id: string }>>`
        SELECT id
        FROM notification_events
        WHERE status IN ('pending', 'failed')
          AND next_attempt_at <= ${now}
          AND attempts < max_attempts
        ORDER BY next_attempt_at ASC
        LIMIT ${batchSize}
        FOR UPDATE SKIP LOCKED
      `;

      if (due.length === 0) return [];

      const ids = due.map((row) => row.id);
      await tx.notification_events.updateMany({
        where: { id: { in: ids } },
        data: {
          status: "processing",
          updated_at: now,
        },
      });

      return tx.notification_events.findMany({
        where: { id: { in: ids } },
      });
    });
  }

  async markSent(
    eventId: string,
    sentAt = new Date(),
  ): Promise<NotificationEvent> {
    return this.db.notification_events.update({
      where: { id: eventId },
      data: {
        status: "sent",
        sent_at: sentAt,
        last_error: null,
        updated_at: sentAt,
      },
    });
  }

  async markAttemptFailed(
    eventId: string,
    error: string,
    nextAttemptAt: Date,
    dead: boolean,
  ): Promise<NotificationEvent> {
    return this.db.notification_events.update({
      where: { id: eventId },
      data: {
        status: dead ? "dead" : "failed",
        attempts: { increment: 1 },
        last_error: error.slice(0, 1000),
        next_attempt_at: nextAttemptAt,
        updated_at: new Date(),
      },
    });
  }

  async addDeliveryLog(input: {
    eventId: string;
    channel: NotificationEvent["channel"];
    provider: string;
    providerMessageId?: string;
    status: string;
    response?: unknown;
  }): Promise<NotificationDeliveryLog> {
    return this.db.notification_delivery_logs.create({
      data: {
        event_id: input.eventId,
        channel: input.channel,
        provider: input.provider,
        provider_message_id: input.providerMessageId,
        status: input.status,
        response:
          input.response === undefined
            ? undefined
            : (input.response as Prisma.InputJsonValue),
      },
    });
  }

  parsePayload(event: NotificationEvent): GroupInvitePayload {
    return asInvitePayload(event.payload);
  }
}
