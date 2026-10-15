import type { IChatRepository } from "../../repositories/chat/i-chat.repository.js";
import { ChatRepository } from "../../repositories/chat/chat.repository.js";
import type {
  ChatMessage,
  CreateChatMessageInput,
} from "../../types/chat/chat.types.js";
import { ValidationError } from "../../utils/errors.js";

export class SendMessageUseCase {
  constructor(private readonly chat: IChatRepository = new ChatRepository()) {}

  async execute(input: CreateChatMessageInput): Promise<ChatMessage> {
    if (!input.outing_id || !input.sender_id || !input.text?.trim()) {
      throw new ValidationError("outing_id, sender_id, and text are required");
    }

    return this.chat.createMessage(input);
  }
}
