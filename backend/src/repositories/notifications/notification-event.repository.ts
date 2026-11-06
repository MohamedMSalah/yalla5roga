import { NotificationEventDatasource } from "../../datasources/notifications/notification-event.datasource.js";
import type {
  EnqueueGroupInviteInput,
  GroupInvitePayload,
  NotificationDeliveryLog,
  NotificationEvent,
} from "../../types/notifications/notification-event.types.js";
import type { INotificationEventRepository } from "./i-notification-event.repository.js";

export class NotificationEventRepository implements INotificationEventRepository {
  constructor(
    private readonly datasource = new NotificationEventDatasource(),
  ) {}

  enqueueGroupInvite(
    input: EnqueueGroupInviteInput,
  ): Promise<NotificationEvent> {
    return this.datasource.enqueueGroupInvite(input);
  }

  claimDue(batchSize: number, now?: Date): Promise<NotificationEvent[]> {
    return this.datasource.claimDue(batchSize, now);
  }

  markSent(eventId: string, sentAt?: Date): Promise<NotificationEvent> {
    return this.datasource.markSent(eventId, sentAt);
  }

  markAttemptFailed(
    eventId: string,
    error: string,
    nextAttemptAt: Date,
    dead: boolean,
  ): Promise<NotificationEvent> {
    return this.datasource.markAttemptFailed(
      eventId,
      error,
      nextAttemptAt,
      dead,
    );
  }

  addDeliveryLog(input: {
    eventId: string;
    channel: NotificationEvent["channel"];
    provider: string;
    providerMessageId?: string;
    status: string;
    response?: unknown;
  }): Promise<NotificationDeliveryLog> {
    return this.datasource.addDeliveryLog(input);
  }

  parsePayload(event: NotificationEvent): GroupInvitePayload {
    return this.datasource.parsePayload(event);
  }
}
