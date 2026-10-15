import type {
  CreateNotificationInput,
  Notification,
  UpdateNotificationInput,
} from "../../types/notifications/notification.types.js";

export interface INotificationRepository {
  findById(id: string): Promise<Notification | null>;
  findByUserId(userId: string): Promise<Notification[]>;
  create(data: CreateNotificationInput): Promise<Notification>;
  update(id: string, data: UpdateNotificationInput): Promise<Notification>;
  markAllRead(userId: string): Promise<{ count: number }>;
  delete(id: string): Promise<Notification>;
}
