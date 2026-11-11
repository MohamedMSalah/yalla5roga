import type {
  ChatMessage,
  ChatHistoryPage,
  ChatRead,
  CreateChatMessageInput,
  UpsertChatReadInput,
} from "../../types/chat/chat.types.js";

export interface IChatRepository {
  findMessageByClientId(outingId: string, senderId: string, clientMessageId: string): Promise<ChatMessage | null>;
  findMessageById(id: string): Promise<ChatMessage | null>;
  findMessagesByOutingId(outingId: string, page?: ChatHistoryPage): Promise<ChatMessage[]>;
  createMessage(data: CreateChatMessageInput): Promise<ChatMessage>;
  upsertRead(data: UpsertChatReadInput): Promise<ChatRead>;
  deleteMessage(id: string): Promise<ChatMessage>;
}
