import { NotificationEventRepository } from "../../repositories/notifications/notification-event.repository.js";
import type { INotificationEventRepository } from "../../repositories/notifications/i-notification-event.repository.js";
import type { EnqueueGroupInviteInput } from "../../types/notifications/notification-event.types.js";

/**
 * Producer side of the notification architecture: API creates an event and
 * returns immediately. The worker consumes from the outbox asynchronously.
 */
export interface NotificationPublisher {
  publishGroupInvite(input: EnqueueGroupInviteInput): Promise<void>;
}

export class OutboxNotificationPublisher implements NotificationPublisher {
  constructor(
    private readonly events: INotificationEventRepository = new NotificationEventRepository(),
  ) {}

  async publishGroupInvite(input: EnqueueGroupInviteInput): Promise<void> {
    await this.events.enqueueGroupInvite({
      ...input,
      channel: input.channel ?? "whatsapp",
    });
  }
}

/** No-op publisher for unit tests that do not exercise the outbox. */
export class NoopNotificationPublisher implements NotificationPublisher {
  readonly published: EnqueueGroupInviteInput[] = [];

  async publishGroupInvite(input: EnqueueGroupInviteInput): Promise<void> {
    this.published.push(input);
  }
}
