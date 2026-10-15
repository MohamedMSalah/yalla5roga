import { prisma } from "../../config/database.js";
import type {
  ChatMessage,
  ChatRead,
  CreateChatMessageInput,
  UpsertChatReadInput,
} from "../../types/chat/chat.types.js";

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

  createMessage(data: CreateChatMessageInput): Promise<ChatMessage> {
    return prisma.chat_messages.create({ data });
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
