import type { IChatRepository } from "../../repositories/chat/i-chat.repository.js";
import { ChatRepository } from "../../repositories/chat/chat.repository.js";
import type { ChatMessage } from "../../types/chat/chat.types.js";

export class ListMessagesUseCase {
  constructor(private readonly chat: IChatRepository = new ChatRepository()) {}

  execute(outingId: string): Promise<ChatMessage[]> {
    return this.chat.findMessagesByOutingId(outingId);
  }
}
