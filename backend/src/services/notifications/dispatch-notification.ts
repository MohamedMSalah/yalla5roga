import { getNotificationConfig } from "../../config/notifications.js";
import { NotificationEventRepository } from "../../repositories/notifications/notification-event.repository.js";
import type { INotificationEventRepository } from "../../repositories/notifications/i-notification-event.repository.js";
import type { NotificationEvent } from "../../types/notifications/notification-event.types.js";
import type { NotificationChannelSender } from "./channels/notification-channel.js";
import { PushChannel } from "./channels/push.channel.js";
import { WhatsAppChannel } from "./channels/whatsapp.channel.js";

function backoffMs(attempt: number): number {
  // 10s, 30s, 90s, 270s, ... capped at 15 minutes
  const base = 10_000 * Math.pow(3, Math.max(0, attempt - 1));
  return Math.min(base, 15 * 60 * 1000);
}

export class NotificationDispatcher {
  constructor(
    private readonly events: INotificationEventRepository = new NotificationEventRepository(),
    private readonly channels: NotificationChannelSender[] = [
      new WhatsAppChannel(),
      new PushChannel(),
    ],
    private readonly config = getNotificationConfig(),
  ) {}

  async processBatch(now = new Date()): Promise<number> {
    const claimed = await this.events.claimDue(
      this.config.worker.batchSize,
      now,
    );

    for (const event of claimed) {
      await this.processOne(event, now);
    }

    return claimed.length;
  }

  private async processOne(
    event: NotificationEvent,
    now: Date,
  ): Promise<void> {
    const channel = this.channels.find((item) => item.channel === event.channel);
    if (!channel) {
      await this.fail(
        event,
        `No sender registered for channel ${event.channel}`,
        now,
        true,
      );
      return;
    }

    const payload = this.events.parsePayload(event);
    const result = await channel.send({
      eventId: event.id,
      channel: event.channel,
      recipientPhone: event.recipient_phone,
      recipientUserId: event.recipient_user_id,
      payload,
    });

    await this.events.addDeliveryLog({
      eventId: event.id,
      channel: event.channel,
      provider: result.provider,
      providerMessageId: result.providerMessageId,
      status: result.status,
      response: result.response ?? { error: result.error },
    });

    if (result.status === "sent") {
      await this.events.markSent(event.id, now);
      return;
    }

    await this.fail(
      event,
      result.error ?? "Channel send failed",
      now,
      false,
    );
  }

  private async fail(
    event: NotificationEvent,
    error: string,
    now: Date,
    forceDead: boolean,
  ): Promise<void> {
    const nextAttempts = event.attempts + 1;
    const dead =
      forceDead || nextAttempts >= event.max_attempts;
    const nextAttemptAt = new Date(now.getTime() + backoffMs(nextAttempts));

    await this.events.markAttemptFailed(
      event.id,
      error,
      nextAttemptAt,
      dead,
    );
  }
}
