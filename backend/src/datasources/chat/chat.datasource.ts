import { Prisma } from "@prisma/client";
import { prisma } from "../../config/database.js";
import type {
  ChatMessage,
  ChatHistoryPage,
  ChatRead,
  CreateChatMessageInput,
  UpsertChatReadInput,
} from "../../types/chat/chat.types.js";

const senderProfile = { users: { select: { name: true, image_url: true } } } as const;

function withSender({ users, ...message }: ChatMessage & {
  users: { name: string; image_url: string | null } | null;
}): ChatMessage {
  return { ...message, sender: users?.name ?? "", avatar: users?.image_url ?? null };
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

  findMessagesByOutingId(outingId: string, page?: ChatHistoryPage): Promise<ChatMessage[]> {
    return prisma.chat_messages.findMany({
      where: { outing_id: outingId },
      include: senderProfile,
      orderBy: [{ sent_at: page ? "desc" : "asc" }, { id: page ? "desc" : "asc" }],
      ...(page && { take: page.limit }),
      ...(page?.before && { cursor: { id: page.before, outing_id: outingId }, skip: 1 }),
    }).then((rows) => (page ? rows.reverse() : rows).map(withSender));
  }

  /**
   * Inserts the message. When the client sent a client_message_id and the
   * same (outing, sender, client_message_id) already exists, the retry hits
   * uq_chat_messages_client_msg and the stored row is returned instead.
   */
  async createMessage(data: CreateChatMessageInput): Promise<ChatMessage> {
    try {
      return withSender(await prisma.chat_messages.create({ data, include: senderProfile }));
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
    const [read] = await prisma.$queryRaw<ChatRead[]>`
      INSERT INTO chat_reads (outing_id, user_id, last_read_at)
      VALUES (${data.outing_id}::uuid, ${data.user_id}, ${data.last_read_at ?? new Date()})
      ON CONFLICT (outing_id, user_id) DO UPDATE
      SET last_read_at = GREATEST(chat_reads.last_read_at, EXCLUDED.last_read_at)
      RETURNING outing_id, user_id, last_read_at
    `;
    return read!;
  }

  deleteMessage(id: string): Promise<ChatMessage> {
    return prisma.chat_messages.delete({ where: { id } });
  }

  async updateMessage(id: string, text: string): Promise<ChatMessage> {
    const changed = await prisma.chat_messages.updateMany({
      where: { id, ...(text ? { text: { not: "" }, sent_at: { gt: new Date(Date.now() - 60_000) } } : {}) }, data: { text },
    });
    if (!changed.count) {
      const { ConflictError } = await import("../../utils/errors.js");
      const current = await this.findMessageById(id);
      throw new ConflictError(current?.text ? "MESSAGE_EDIT_WINDOW_EXPIRED" : "MESSAGE_DELETED");
    }
    return (await this.findMessageById(id))!;
  }
}
