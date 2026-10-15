import { prisma } from "../../config/database.js";
import type {
  CreateNotificationInput,
  Notification,
  UpdateNotificationInput,
} from "../../types/notifications/notification.types.js";

export class NotificationDatasource {
  findById(id: string): Promise<Notification | null> {
    return prisma.notifications.findUnique({ where: { id } });
  }

  findByUserId(userId: string): Promise<Notification[]> {
    return prisma.notifications.findMany({
      where: { user_id: userId },
      orderBy: { created_at: "desc" },
    });
  }

  create(data: CreateNotificationInput): Promise<Notification> {
    return prisma.notifications.create({ data });
  }

  update(id: string, data: UpdateNotificationInput): Promise<Notification> {
    return prisma.notifications.update({ where: { id }, data });
  }

  markAllRead(userId: string): Promise<{ count: number }> {
    return prisma.notifications.updateMany({
      where: { user_id: userId, is_read: false },
      data: { is_read: true },
    });
  }

  delete(id: string): Promise<Notification> {
    return prisma.notifications.delete({ where: { id } });
  }
}
