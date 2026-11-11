import type {
  notification_channel,
  notification_delivery_logs,
  notification_event_status,
  notification_event_type,
  notification_events,
} from "@prisma/client";

export type NotificationEvent = notification_events;
export type NotificationDeliveryLog = notification_delivery_logs;
export type NotificationChannel = notification_channel;
export type NotificationEventStatus = notification_event_status;
export type NotificationEventType = notification_event_type;

export type GroupInvitePayload = {
  whatsappOptIn?: boolean;
  invitationId: string;
  groupId: string;
  groupName: string;
  inviterName: string;
  invitedPhone: string;
  deepLink: string;
  appDeepLink: string;
  body: string;
};

export type EnqueueGroupInviteInput = {
  whatsappOptIn?: boolean;
  invitationId: string;
  groupId: string;
  groupName: string;
  inviterUserId: string;
  inviterName: string;
  invitedPhone: string;
  deepLink: string;
  appDeepLink: string;
  body: string;
  channel?: NotificationChannel;
  maxAttempts?: number;
};

export type ClaimedNotificationEvent = NotificationEvent & {
  payload: GroupInvitePayload;
};
