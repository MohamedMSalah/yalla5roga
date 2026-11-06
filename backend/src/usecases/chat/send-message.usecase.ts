import type { IChatRepository } from "../../repositories/chat/i-chat.repository.js";
import { ChatRepository } from "../../repositories/chat/chat.repository.js";
import { assertCanChat } from "../../services/chat/chat-access.js";
import { notifyOutingParticipants } from "../../services/notifications/outing-notifier.js";
import { prisma } from "../../config/database.js";
import type {
  ChatMessage,
  CreateChatMessageInput,
} from "../../types/chat/chat.types.js";
import { NotFoundError, ValidationError } from "../../utils/errors.js";

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

    const message = await this.chat.createMessage({
      outing_id: input.outing_id,
      sender_id: input.sender_id,
      text: input.text,
      client_message_id: input.client_message_id ?? null,
    });

    const outing = await prisma.outings.findUnique({
      where: { id: input.outing_id },
    });
    if (!outing) throw new NotFoundError("Outing");

    await notifyOutingParticipants({
      outing,
      type: "chat",
      eventType: "chat_message",
      body: `New message in "${outing.title}"`,
      eventKey: `chat_message:${message.id}`,
      excludeUserId: input.sender_id,
    });

    return message;
  }
}
