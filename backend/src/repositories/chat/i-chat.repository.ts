import type {
  ChatMessage,
  ChatRead,
  CreateChatMessageInput,
  UpsertChatReadInput,
} from "../../types/chat/chat.types.js";

export interface IChatRepository {
  findMessageById(id: string): Promise<ChatMessage | null>;
  findMessagesByOutingId(outingId: string): Promise<ChatMessage[]>;
  createMessage(data: CreateChatMessageInput): Promise<ChatMessage>;
  upsertRead(data: UpsertChatReadInput): Promise<ChatRead>;
  deleteMessage(id: string): Promise<ChatMessage>;
}
