import { Prisma } from "@prisma/client";
import { prisma } from "../../config/database.js";
import {
  chatParticipantIds,
  mentionedUserIds,
} from "../../services/chat/chat-mentions.js";
import {
  persistNotifications,
  persistNotificationControl,
} from "../../services/notifications/persist-notification.js";
import { ConflictError, ForbiddenError } from "../../utils/errors.js";
import type {
  ChatMessage,
  ChatHistoryPage,
  ChatRead,
  CreateChatMessageInput,
  UpsertChatReadInput,
} from "../../types/chat/chat.types.js";

const senderProfile = { users: { select: { name: true, image_url: true } },
} as const;

function withSender({ users, ...message }: ChatMessage & {
  users: { name: string; image_url: string | null } | null;
}): ChatMessage {
  return { ...message, sender: users?.name ?? "", avatar: users?.image_url ?? null,
  };
}

function isUniqueViolation(error: unknown): boolean {
  return (
    error instanceof Prisma.PrismaClientKnownRequestError &&
    error.code === "P2002"
  );
}

export class ChatDatasource {
  async findMessageById(id: string): Promise<ChatMessage | null> {
    const message = await prisma.chat_messages.findUnique({
      where: { id },
      include: senderProfile,
    });
    return message ? withSender(message) : null;
  }

  async findMessageByClientId(
    outingId: string, senderId: string, clientMessageId: string,
  ): Promise<ChatMessage | null> {
    const message = await prisma.chat_messages.findUnique({
      where: {
        outing_id_sender_id_client_message_id: {
          outing_id: outingId, sender_id: senderId, client_message_id: clientMessageId,
        },
      },
      include: senderProfile,
    });
    return message ? withSender(message) : null;
  }

  findMessagesByOutingId(outingId: string, page?: ChatHistoryPage,
  ): Promise<ChatMessage[]> {
    return prisma.chat_messages.findMany({
      where: { outing_id: outingId },
      include: senderProfile,
      orderBy: [{ sent_at: page ? "desc" : "asc" }, { id: page ? "desc" : "asc" },
        ],
      ...(page && { take: page.limit }),
      ...(page?.before && { cursor: { id: page.before, outing_id: outingId }, skip: 1,
        }),
    }).then((rows) => (page ? rows.reverse() : rows).map(withSender));
  }

  /**
   * Inserts the message. When the client sent a client_message_id and the
   * same (outing, sender, client_message_id) already exists, the retry hits
   * uq_chat_messages_client_msg and the stored row is returned instead.
   */
  async createMessage(data: CreateChatMessageInput): Promise<ChatMessage> {
    try {
      return await prisma.$transaction(async (tx) => {
        await tx.$queryRaw`SELECT id FROM outings WHERE id = ${data.outing_id}::uuid FOR SHARE`;
        const outing = await tx.outings.findUniqueOrThrow({
          where: { id: data.outing_id },
        });
        if (outing.group_id)
          await tx.$queryRaw`SELECT group_id FROM group_members WHERE group_id = ${outing.group_id}::uuid AND user_id = ${data.sender_id} FOR KEY SHARE`;
        const audience = await chatParticipantIds(outing, tx);
        if (!audience.includes(data.sender_id))
          throw new ForbiddenError("NOT_A_PARTICIPANT");
        if (
          ["cancelled", "past"].includes(outing.status) ||
          (outing.scheduled_at &&
            outing.scheduled_at.getTime() + 7_200_000 <= Date.now())
        )
          throw new ConflictError("CHAT_CLOSED");
        const message = withSender(await tx.chat_messages.create({ data, include: senderProfile }),
        );
        const recipients = audience.filter((id) => id !== data.sender_id);
        const mentions = new Set(mentionedUserIds(message.text));
        for (const mentioned of [false, true]) {
          await persistNotifications(tx, {
            recipients: recipients.filter(
              (id) => mentions.has(id) === mentioned,
            ),
            eventKey: `chat_message:${message.id}`,
            eventType: "chat_message",
            type: "chat",
            title: `${message.sender} — ${outing.title}`,
            body: message.text.replace(
              /<@[^|<>]+\|([^<>]*)>/g,
              (_, name: string) => `@${decodeURIComponent(name)}`,
            ),
            outingId: outing.id,
            groupId: outing.group_id,
            messageId: message.id,
            data: {
              senderName: message.sender ?? "",
              senderId: message.sender_id,
              conversationTitle: outing.title,
              mention: String(mentioned),
              messageSentAt: message.sent_at.toISOString(),
            },
          });
        }
        return message;
      });
    } catch (error) {
      if (!isUniqueViolation(error) || !data.client_message_id) throw error;

      const existing = await this.findMessageByClientId(
        data.outing_id, data.sender_id, data.client_message_id,
      );
      if (!existing) throw error;
      return existing;
    }
  }

  async upsertRead(data: UpsertChatReadInput): Promise<ChatRead> {
    return prisma.$transaction(async (tx) => {
      const [read] = await tx.$queryRaw<ChatRead[]>`
      INSERT INTO chat_reads (outing_id, user_id, last_read_at)
      VALUES (${data.outing_id}::uuid, ${data.user_id}, ${data.last_read_at ?? new Date()})
      ON CONFLICT (outing_id, user_id) DO UPDATE
      SET last_read_at = GREATEST(chat_reads.last_read_at, EXCLUDED.last_read_at)
      RETURNING outing_id, user_id, last_read_at
    `;
      await tx.notifications.updateMany({
        where: {
          user_id: data.user_id,
          outing_id: data.outing_id,
          type: "chat",
          is_read: false,
          created_at: { lte: read!.last_read_at },
        },
        data: { is_read: true },
      });
      await persistNotificationControl(tx, {
        recipients: [data.user_id],
        type: "conversation_read",
        outingId: data.outing_id,
        eventKey: `conversation_read:${data.outing_id}:${read!.last_read_at.toISOString()}`,
        data: { readAt: read!.last_read_at.toISOString() },
      });
      return read!;
    });
  }

  deleteMessage(id: string): Promise<ChatMessage> {
    return prisma.chat_messages.delete({ where: { id } });
  }

  async updateMessage(id: string, text: string): Promise<ChatMessage> {
    return prisma.$transaction(async (tx) => {
      const changed = await tx.chat_messages.updateMany({
      where: { id, ...(text ? { text: { not: "" }, sent_at: { gt: new Date(Date.now() - 60_000) },
              } : {}),
        }, data: { text },
    });
    if (!changed.count) {
      const { ConflictError } = await import("../../utils/errors.js");
      const current = await tx.chat_messages.findUnique({ where: { id } });
      throw new ConflictError(current?.text ? "MESSAGE_EDIT_WINDOW_EXPIRED" : "MESSAGE_DELETED",
        );
    }
      const saved = withSender(await tx.chat_messages.findUniqueOrThrow({
          where: { id },
          include: senderProfile,
        }),
      );
      const inbox = await tx.notifications.findMany({
        where: { event_key: { startsWith: `chat_message:${id}:` } },
      });
      const preview = text
        .replace(
          /<@[^|<>]+\|([^<>]*)>/g,
          (_, name: string) => `@${decodeURIComponent(name)}`,
        )
        .slice(0, 500);
      for (const row of inbox) {
        const metadata = row.data as Record<string, string>;
        await tx.notifications.update({
          where: { id: row.id },
          data: {
            body: text ? preview : "Message deleted",
            is_read: text ? row.is_read : true,
            data: {
              ...metadata,
              body: text ? preview : "Message deleted",
              deleted: String(!text),
            },
          },
        });
      }
      await persistNotificationControl(tx, {
        recipients: inbox.map((row) => row.user_id),
        type: text ? "chat_updated" : "chat_deleted",
        outingId: saved.outing_id,
        messageId: id,
        eventKey: `chat_mutation:${id}:${text ? new Date().toISOString() : "deleted"}`,
      });
      return saved;
    });
  }
}
