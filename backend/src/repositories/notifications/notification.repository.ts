import { NotificationDatasource } from "../../datasources/notifications/notification.datasource.js";
import type {
  CreateNotificationInput,
  Notification,
  UpdateNotificationInput,
} from "../../types/notifications/notification.types.js";
import type {
  INotificationRepository,
  NotificationPage,
  NotificationPageResult,
} from "./i-notification.repository.js";

export class NotificationRepository implements INotificationRepository {
  constructor(private readonly datasource = new NotificationDatasource()) {}

  findById(id: string): Promise<Notification | null> {
    return this.datasource.findById(id);
  }

  findByUserId(userId: string): Promise<Notification[]> {
    return this.datasource.findByUserId(userId);
  }

  findPageByUserId(
    userId: string,
    page: NotificationPage,
  ): Promise<NotificationPageResult> {
    return this.datasource.findPageByUserId(userId, page);
  }

  create(data: CreateNotificationInput): Promise<Notification> {
    return this.datasource.create(data);
  }

  update(id: string, data: UpdateNotificationInput): Promise<Notification> {
    return this.datasource.update(id, data);
  }

  markAllRead(userId: string): Promise<{ count: number }> {
    return this.datasource.markAllRead(userId);
  }

  delete(id: string): Promise<Notification> {
    return this.datasource.delete(id);
  }
}
