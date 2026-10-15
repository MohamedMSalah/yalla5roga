import { ChatDatasource } from "../../datasources/chat/chat.datasource.js";
import type {
  ChatMessage,
  ChatRead,
  CreateChatMessageInput,
  UpsertChatReadInput,
} from "../../types/chat/chat.types.js";
import type { IChatRepository } from "./i-chat.repository.js";

export class ChatRepository implements IChatRepository {
  constructor(private readonly datasource = new ChatDatasource()) {}

  findMessageById(id: string): Promise<ChatMessage | null> {
    return this.datasource.findMessageById(id);
  }

  findMessagesByOutingId(outingId: string): Promise<ChatMessage[]> {
    return this.datasource.findMessagesByOutingId(outingId);
  }

  createMessage(data: CreateChatMessageInput): Promise<ChatMessage> {
    return this.datasource.createMessage(data);
  }

  upsertRead(data: UpsertChatReadInput): Promise<ChatRead> {
    return this.datasource.upsertRead(data);
  }

  deleteMessage(id: string): Promise<ChatMessage> {
    return this.datasource.deleteMessage(id);
  }
}
