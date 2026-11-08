import type { IChatRepository } from "../../repositories/chat/i-chat.repository.js";
import { ChatRepository } from "../../repositories/chat/chat.repository.js";
import { assertChatParticipant } from "../../services/chat/chat-access.js";
import { emitOutingRead } from "../../realtime/chat-emitter.js";
import type { ChatRead } from "../../types/chat/chat.types.js";

export class MarkChatReadUseCase {
  constructor(
    private readonly chat: IChatRepository = new ChatRepository(),
    private readonly guard: typeof assertChatParticipant = assertChatParticipant,
  ) {}

  /**
   * Upserts `chat_reads` for the caller on this outing so unread badges
   * can be derived from `last_read_at` vs message `sent_at`.
   * Emits `outing:read` to the outing room after persistence.
   */
  async execute(outingId: string, userId: string): Promise<ChatRead> {
    await this.guard(outingId, userId);
    const read = await this.chat.upsertRead({
      outing_id: outingId,
      user_id: userId,
      last_read_at: new Date(),
    });
    emitOutingRead(outingId, read);
    return read;
  }
}
