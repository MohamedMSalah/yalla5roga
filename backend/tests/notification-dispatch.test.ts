import assert from "node:assert/strict";
import { describe, it } from "node:test";
import type { INotificationEventRepository } from "../src/repositories/notifications/i-notification-event.repository.js";
import { NotificationDispatcher } from "../src/services/notifications/dispatch-notification.js";
import type {
  ChannelSendInput,
  ChannelSendResult,
  NotificationChannelSender,
} from "../src/services/notifications/channels/notification-channel.js";
import type {
  EnqueueGroupInviteInput,
  GroupInvitePayload,
  NotificationDeliveryLog,
  NotificationEvent,
} from "../src/types/notifications/notification-event.types.js";

const NOW = new Date("2026-11-06T12:00:00.000Z");

function invitePayload(
  overrides: Partial<GroupInvitePayload> = {},
): GroupInvitePayload {
  return {
    invitationId: "invite-1",
    groupId: "group-1",
    groupName: "Friday Squad",
    inviterName: "Mona",
    invitedPhone: "+201001234567",
    deepLink: "https://yalla5roga.com/invite/invite-1?groupId=group-1",
    appDeepLink: "yalla5roga://invite?invitationId=invite-1&groupId=group-1",
    body: "Open your invite here:\nhttps://yalla5roga.com/invite/invite-1?groupId=group-1",
    ...overrides,
  };
}

function event(overrides: Partial<NotificationEvent> = {}): NotificationEvent {
  return {
    id: "event-1",
    type: "group_invite",
    channel: "whatsapp",
    status: "processing",
    recipient_phone: "+201001234567",
    recipient_user_id: null,
    group_id: "group-1",
    invitation_id: "invite-1",
    payload: invitePayload(),
    attempts: 0,
    max_attempts: 5,
    next_attempt_at: NOW,
    last_error: null,
    sent_at: null,
    created_at: NOW,
    updated_at: NOW,
    ...overrides,
  } as NotificationEvent;
}

class FakeEvents implements INotificationEventRepository {
  claimed: NotificationEvent[] = [];
  sent: string[] = [];
  failed: Array<{ id: string; error: string; dead: boolean }> = [];
  logs: Array<{ eventId: string; status: string; provider: string }> = [];

  enqueueGroupInvite(_input: EnqueueGroupInviteInput): Promise<NotificationEvent> {
    throw new Error("not used");
  }

  claimDue(): Promise<NotificationEvent[]> {
    return Promise.resolve(this.claimed);
  }

  markSent(eventId: string): Promise<NotificationEvent> {
    this.sent.push(eventId);
    return Promise.resolve(event({ id: eventId, status: "sent" }));
  }

  markAttemptFailed(
    eventId: string,
    error: string,
    _nextAttemptAt: Date,
    dead: boolean,
  ): Promise<NotificationEvent> {
    this.failed.push({ id: eventId, error, dead });
    return Promise.resolve(
      event({ id: eventId, status: dead ? "dead" : "failed" }),
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
    this.logs.push({
      eventId: input.eventId,
      status: input.status,
      provider: input.provider,
    });
    return Promise.resolve({
      id: "log-1",
      event_id: input.eventId,
      channel: input.channel,
      provider: input.provider,
      provider_message_id: input.providerMessageId ?? null,
      status: input.status,
      response: null,
      created_at: NOW,
    });
  }

  parsePayload(item: NotificationEvent): GroupInvitePayload {
    return item.payload as unknown as GroupInvitePayload;
  }
}

class FakeChannel implements NotificationChannelSender {
  constructor(readonly channel: NotificationEvent["channel"] = "whatsapp") {}
  result: ChannelSendResult = {
    provider: "stub",
    providerMessageId: "msg-1",
    status: "sent",
  };
  calls: ChannelSendInput[] = [];

  send(input: ChannelSendInput): Promise<ChannelSendResult> {
    this.calls.push(input);
    return Promise.resolve(this.result);
  }
}

describe("notification dispatcher", () => {
  it("marks WhatsApp deliveries as sent and writes a delivery log", async () => {
    const events = new FakeEvents();
    const whatsapp = new FakeChannel();
    events.claimed = [event()];
    const dispatcher = new NotificationDispatcher(events, [whatsapp], {
      deepLinkBaseUrl: "https://yalla5roga.com",
      appScheme: "yalla5roga",
      whatsapp: {
        provider: "stub",
        accessToken: "",
        phoneNumberId: "",
        apiVersion: "v21.0",
        templateName: "group_invite",
        templateLanguage: "en",
      },
      worker: { intervalMs: 5000, batchSize: 20, maxAttempts: 5 },
    });

    const count = await dispatcher.processBatch(NOW);

    assert.equal(count, 1);
    assert.deepEqual(events.sent, ["event-1"]);
    assert.equal(events.failed.length, 0);
    assert.equal(events.logs[0]?.status, "sent");
    assert.equal(whatsapp.calls[0]?.payload.deepLink.includes("/invite/"), true);
  });

  it("normalizes queued chat events and keeps their inbox identity", async () => {
    const events = new FakeEvents();
    const push = new FakeChannel("push");
    events.claimed = [event({
      type: "chat_message",
      channel: "push",
      recipient_user_id: "recipient",
      outing_id: "outing-1",
      event_key: "outbox:chat_message:message-1:recipient",
      payload: { notification_type: "chat", outing_id: "outing-1", body: "New message" },
    })];

    await new NotificationDispatcher(events, [push]).processBatch(NOW);

    assert.equal(push.calls[0]?.inboxEventKey, "chat_message:message-1:recipient");
    assert.equal(push.calls[0]?.payload.type, "chat_message");
    assert.equal(push.calls[0]?.payload.groupId, "group-1");
    assert.equal(push.calls[0]?.payload.outingId, "outing-1");
    assert.equal(push.calls[0]?.payload.messageId, "message-1");
  });

  it("retries failed WhatsApp sends without killing the event on first failure", async () => {
    const events = new FakeEvents();
    const whatsapp = new FakeChannel();
    whatsapp.result = {
      provider: "meta",
      status: "failed",
      error: "rate limited",
    };
    events.claimed = [event()];
    const dispatcher = new NotificationDispatcher(events, [whatsapp], {
      deepLinkBaseUrl: "https://yalla5roga.com",
      appScheme: "yalla5roga",
      whatsapp: {
        provider: "meta",
        accessToken: "token",
        phoneNumberId: "phone",
        apiVersion: "v21.0",
        templateName: "group_invite",
        templateLanguage: "en",
      },
      worker: { intervalMs: 5000, batchSize: 20, maxAttempts: 5 },
    });

    await dispatcher.processBatch(NOW);

    assert.equal(events.sent.length, 0);
    assert.equal(events.failed.length, 1);
    assert.equal(events.failed[0]?.dead, false);
    assert.equal(events.failed[0]?.error, "rate limited");
  });
});
