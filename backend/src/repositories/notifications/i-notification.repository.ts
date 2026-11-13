import type {
  CreateNotificationInput,
  Notification,
  UpdateNotificationInput,
} from "../../types/notifications/notification.types.js";

export type NotificationPage = {
  limit: number;
  cursor?: string;
};

export type NotificationPageResult = {
  items: Notification[];
  nextCursor: string | null;
};

export interface INotificationRepository {
  findById(id: string): Promise<Notification | null>;
  findByUserId(userId: string): Promise<Notification[]>;
  findPageByUserId(
    userId: string,
    page: NotificationPage,
  ): Promise<NotificationPageResult>;
  create(data: CreateNotificationInput): Promise<Notification>;
  update(id: string, data: UpdateNotificationInput): Promise<Notification>;
  markAllRead(userId: string): Promise<{ count: number }>;
  delete(id: string): Promise<Notification>;
}
