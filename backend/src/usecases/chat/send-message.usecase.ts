import type { IChatRepository } from "../../repositories/chat/i-chat.repository.js";
import { ChatRepository } from "../../repositories/chat/chat.repository.js";
import { assertCanChat } from "../../services/chat/chat-access.js";
import type {
  ChatMessage,
  CreateChatMessageInput,
} from "../../types/chat/chat.types.js";
import { ValidationError } from "../../utils/errors.js";

export class SendMessageUseCase {
  constructor(
    private readonly chat: IChatRepository = new ChatRepository(),
    private readonly guard: typeof assertCanChat = assertCanChat,
  ) {}

  async execute(input: CreateChatMessageInput): Promise<ChatMessage> {
    if (!input.outing_id || !input.sender_id || !input.text?.trim()) {
      throw new ValidationError("outing_id, sender_id, and text are required");
    }

    await this.guard(input.outing_id, input.sender_id);

    return this.chat.createMessage({
      outing_id: input.outing_id,
      sender_id: input.sender_id,
      text: input.text,
      client_message_id: input.client_message_id ?? null,
    });
  }
}
