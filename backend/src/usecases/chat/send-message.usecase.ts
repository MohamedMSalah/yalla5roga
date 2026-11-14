import type { IChatRepository } from "../../repositories/chat/i-chat.repository.js";
import { ChatRepository } from "../../repositories/chat/chat.repository.js";
import { assertCanChat } from "../../services/chat/chat-access.js";
import { emitOutingMessage } from "../../realtime/chat-emitter.js";
import { prisma } from "../../config/database.js";
import { canonicalizeMentions } from "../../services/chat/chat-mentions.js";
import type {
  ChatMessage,
  CreateChatMessageInput,
} from "../../types/chat/chat.types.js";
import { ConflictError, NotFoundError, ValidationError,
} from "../../utils/errors.js";

import { emitDataChange, outingRealtimeUsers,
} from "../../realtime/data-changes.js";

export class SendMessageUseCase {
  constructor(
    private readonly chat: IChatRepository = new ChatRepository(),
    private readonly guard: typeof assertCanChat = assertCanChat,
  ) {}

  async execute(input: CreateChatMessageInput): Promise<ChatMessage> {
    if (!input.outing_id || !input.sender_id || !input.text?.trim()) {
      throw new ValidationError("outing_id, sender_id, and text are required");
    }

    let committed: ChatMessage | null = null;
    try {
      await this.guard(input.outing_id, input.sender_id);
    } catch (error) {
      // The close check follows the participant check. A retry can acknowledge
      // a previously committed write without reopening the chat.
      if (error instanceof ConflictError && input.client_message_id) {
        const existing = await this.chat.findMessageByClientId(
          input.outing_id, input.sender_id, input.client_message_id,
        );
        committed = existing;
      }
      if (!committed) throw error;
    }

    const outing = await prisma.outings.findUnique({ where: { id: input.outing_id },
    });
    if (!outing) throw new NotFoundError("Outing");
    const existing = committed ?? (input.client_message_id
      ? await this.chat.findMessageByClientId(input.outing_id, input.sender_id, input.client_message_id,
          )
      : null);
    // Reuse the committed tokens on retries, including after member/name changes.
    const text = existing ? existing.text : await canonicalizeMentions(input.text, outing);
    if (!existing) await this.guard(input.outing_id, input.sender_id);
    const message = existing ??
      (await this.chat.createMessage({
      outing_id: input.outing_id,
      sender_id: input.sender_id,
      text,
      client_message_id: input.client_message_id ?? null,
    }));

    // Real-time delivery after durable write (idempotent retries reuse same id).
    const audience = await outingRealtimeUsers(input.outing_id);
    await emitOutingMessage(input.outing_id, message, audience);

    emitDataChange({ kind: "inbox" }, audience.filter((id) => id !== input.sender_id),
    );
    return message;
  }
}
