import type { IChatRepository } from "../../repositories/chat/i-chat.repository.js";
import { ChatRepository } from "../../repositories/chat/chat.repository.js";
import { assertChatParticipant } from "../../services/chat/chat-access.js";
import type { ChatMessage } from "../../types/chat/chat.types.js";

export class ListMessagesUseCase {
  constructor(
    private readonly chat: IChatRepository = new ChatRepository(),
    private readonly guard: typeof assertChatParticipant = assertChatParticipant,
  ) {}

  /** History stays readable after the outing ends; only participation is checked. */
  async execute(outingId: string, userId: string): Promise<ChatMessage[]> {
    await this.guard(outingId, userId);
    return this.chat.findMessagesByOutingId(outingId);
  }
}
