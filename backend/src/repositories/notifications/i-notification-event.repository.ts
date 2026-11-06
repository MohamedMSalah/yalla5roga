import type {
  EnqueueGroupInviteInput,
  GroupInvitePayload,
  NotificationDeliveryLog,
  NotificationEvent,
} from "../../types/notifications/notification-event.types.js";

export interface INotificationEventRepository {
  enqueueGroupInvite(input: EnqueueGroupInviteInput): Promise<NotificationEvent>;
  claimDue(batchSize: number, now?: Date): Promise<NotificationEvent[]>;
  markSent(eventId: string, sentAt?: Date): Promise<NotificationEvent>;
  markAttemptFailed(
    eventId: string,
    error: string,
    nextAttemptAt: Date,
    dead: boolean,
  ): Promise<NotificationEvent>;
  addDeliveryLog(input: {
    eventId: string;
    channel: NotificationEvent["channel"];
    provider: string;
    providerMessageId?: string;
    status: string;
    response?: unknown;
  }): Promise<NotificationDeliveryLog>;
  parsePayload(event: NotificationEvent): GroupInvitePayload;
}
