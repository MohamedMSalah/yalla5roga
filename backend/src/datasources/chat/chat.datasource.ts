import { Prisma } from "@prisma/client";
import { prisma } from "../../config/database.js";
import type {
  ChatMessage,
  ChatRead,
  CreateChatMessageInput,
  UpsertChatReadInput,
} from "../../types/chat/chat.types.js";

function isUniqueViolation(error: unknown): boolean {
  return (
    error instanceof Prisma.PrismaClientKnownRequestError &&
    error.code === "P2002"
  );
}

export class ChatDatasource {
  findMessageById(id: string): Promise<ChatMessage | null> {
    return prisma.chat_messages.findUnique({ where: { id } });
  }

  findMessagesByOutingId(outingId: string): Promise<ChatMessage[]> {
    return prisma.chat_messages.findMany({
      where: { outing_id: outingId },
      orderBy: { sent_at: "asc" },
    });
  }

  /**
   * Inserts the message. When the client sent a client_message_id and the
   * same (outing, sender, client_message_id) already exists, the retry hits
   * uq_chat_messages_client_msg and the stored row is returned instead.
   */
  async createMessage(data: CreateChatMessageInput): Promise<ChatMessage> {
    try {
      return await prisma.chat_messages.create({ data });
    } catch (error) {
      if (!isUniqueViolation(error) || !data.client_message_id) throw error;

      const existing = await prisma.chat_messages.findFirst({
        where: {
          outing_id: data.outing_id,
          sender_id: data.sender_id,
          client_message_id: data.client_message_id,
        },
      });
      if (!existing) throw error;
      return existing;
    }
  }

  upsertRead(data: UpsertChatReadInput): Promise<ChatRead> {
    return prisma.chat_reads.upsert({
      where: {
        outing_id_user_id: {
          outing_id: data.outing_id,
          user_id: data.user_id,
        },
      },
      create: {
        outing_id: data.outing_id,
        user_id: data.user_id,
        last_read_at: data.last_read_at ?? new Date(),
      },
      update: {
        last_read_at: data.last_read_at ?? new Date(),
      },
    });
  }

  deleteMessage(id: string): Promise<ChatMessage> {
    return prisma.chat_messages.delete({ where: { id } });
  }
}
