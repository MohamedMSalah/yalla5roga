import { prisma } from "../../config/database.js";
import type {
  CreateNotificationInput,
  Notification,
  UpdateNotificationInput,
} from "../../types/notifications/notification.types.js";
import type {
  NotificationPage,
  NotificationPageResult,
} from "../../repositories/notifications/i-notification.repository.js";
import { ValidationError } from "../../utils/errors.js";
import { notificationPreferences } from "../../services/notifications/notification-preferences.js";
import { persistNotificationControl } from "../../services/notifications/persist-notification.js";

export class NotificationDatasource {
  async summary(uid: string) {
    const user = await prisma.users.findUniqueOrThrow({
      where: { id: uid },
      select: {
        notification_preferences: true,
        _count: { select: { notifications: { where: { is_read: false } } } },
      },
    });
    return {
      unreadCount: user._count.notifications,
      preferences: notificationPreferences(user.notification_preferences),
    };
  }

  updatePreferences(uid: string, patch: Record<string, boolean>) {
    return prisma.$transaction(async (tx) => {
      await tx.$queryRaw`SELECT id FROM users WHERE id = ${uid} FOR UPDATE`;
      const user = await tx.users.findUniqueOrThrow({ where: { id: uid } });
      const preferences = {
        ...notificationPreferences(user.notification_preferences),
        ...patch,
      };
      await tx.users.update({
        where: { id: uid },
        data: { notification_preferences: preferences },
      });
      return preferences;
    });
  }
  findById(id: string): Promise<Notification | null> {
    return prisma.notifications.findUnique({ where: { id } });
  }

  findByUserId(userId: string): Promise<Notification[]> {
    return prisma.notifications.findMany({
      where: { user_id: userId },
      orderBy: { created_at: "desc" },
    });
  }

  /**
   * Keyset pagination on `(created_at desc, id desc)` so rows inserted while
   * the client pages do not shift the window. The cursor is the id of the last
   * row the caller received and must belong to the same user.
   */
  async findPageByUserId(
    userId: string,
    page: NotificationPage,
  ): Promise<NotificationPageResult> {
    let cursorId: string | undefined;
    if (page.cursor) {
      try {
        cursorId = Buffer.from(page.cursor, "base64url").toString("utf8");
        if (!/^[0-9a-f-]{36}$/i.test(cursorId) || Buffer.from(cursorId).toString("base64url") !== page.cursor) throw new Error();
      } catch { throw new ValidationError("Invalid notification cursor"); }
    }
    const anchor = cursorId
      ? await prisma.notifications.findFirst({
          where: { id: cursorId, user_id: userId },
          select: { id: true, created_at: true },
        })
      : null;
    if (page.cursor && !anchor) {
      throw new ValidationError("Invalid notification cursor");
    }

    const rows = await prisma.notifications.findMany({
      where: {
        user_id: userId,
      },
      ...(anchor ? { cursor: { id: anchor.id }, skip: 1 } : {}),
      orderBy: [{ created_at: "desc" }, { id: "desc" }],
      take: page.limit + 1,
    });

    const hasMore = rows.length > page.limit;
    const items = hasMore ? rows.slice(0, page.limit) : rows;
    return {
      items,
      nextCursor: hasMore && items.length ? Buffer.from(items[items.length - 1]!.id).toString("base64url") : null,
    };
  }

  create(data: CreateNotificationInput): Promise<Notification> {
    return prisma.notifications.create({ data });
  }

  update(id: string, data: UpdateNotificationInput): Promise<Notification> {
    return prisma.$transaction(async (tx) => {
      const row = await tx.notifications.update({ where: { id }, data });
      if (data.is_read)
        await persistNotificationControl(tx, {
          recipients: [row.user_id],
          type: "conversation_read",
          eventKey: `notification_read:${id}`,
          data: { notificationId: id },
        });
      return row;
    });
  }

  markAllRead(userId: string): Promise<{ count: number }> {
    return prisma.$transaction(async (tx) => {
      const now = new Date();
      const result = await tx.notifications.updateMany({
      where: { user_id: userId, is_read: false, created_at: { lte: now } },
      data: { is_read: true },
      });
      if (result.count)
        await persistNotificationControl(tx, {
          recipients: [userId],
          type: "conversation_read",
          eventKey: `notifications_read:${userId}:${now.toISOString()}`,
          data: { readAll: "true", createdAt: now.toISOString() },
        });
      return result;
    });
  }

  delete(id: string): Promise<Notification> {
    return prisma.notifications.delete({ where: { id } });
  }
}
