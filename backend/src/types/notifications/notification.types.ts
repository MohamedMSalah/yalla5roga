import type { notification_type, notifications } from "@prisma/client";

export type Notification = notifications;
export type NotificationType = notification_type;

export type CreateNotificationInput = {
  user_id: string;
  body: string;
  image_url?: string | null;
  type?: NotificationType;
  outing_id?: string | null;
  group_id?: string | null;
  action_required?: boolean;
};

export type UpdateNotificationInput = {
  is_read?: boolean;
  action_required?: boolean;
};
