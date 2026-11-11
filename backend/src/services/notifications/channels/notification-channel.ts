import type { NotificationChannel } from "../../../types/notifications/notification-event.types.js";
import type { GroupInvitePayload } from "../../../types/notifications/notification-event.types.js";

export type ChannelSendResult = {
  provider: string;
  providerMessageId?: string;
  status: "sent" | "failed";
  response?: unknown;
  error?: string;
  retryable?: boolean;
  /** When set, dispatcher may delete invalid FCM tokens. */
  invalidTokens?: string[];
};

export type PushPayload = {
  body?: string;
  title?: string;
  outing_id?: string;
  notification_type?: string;
  [key: string]: unknown;
};

export type ChannelSendInput = {
  eventId: string;
  channel: NotificationChannel;
  recipientPhone: string | null;
  recipientUserId: string | null;
  inboxEventKey?: string | null;
  payload: GroupInvitePayload | PushPayload | Record<string, unknown>;
};

export interface NotificationChannelSender {
  readonly channel: NotificationChannel;
  send(input: ChannelSendInput): Promise<ChannelSendResult>;
}
