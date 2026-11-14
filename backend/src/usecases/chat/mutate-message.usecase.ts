import { prisma } from "../../config/database.js";
import { ChatRepository } from "../../repositories/chat/chat.repository.js";
import { assertCanChat } from "../../services/chat/chat-access.js";
import { canonicalizeMentions } from "../../services/chat/chat-mentions.js";
import { emitOutingMessage } from "../../realtime/chat-emitter.js";
import { outingRealtimeUsers } from "../../realtime/data-changes.js";
import { ConflictError, ForbiddenError, NotFoundError } from "../../utils/errors.js";

export class MutateMessageUseCase {
  constructor(private readonly chat = new ChatRepository()) {}

  async execute(outingId: string, messageId: string, uid: string, text: string | null) {
    await assertCanChat(outingId, uid);
    const message = await this.chat.findMessageById(messageId);
    if (!message || message.outing_id !== outingId) throw new NotFoundError("Message");
    if (message.sender_id !== uid) throw new ForbiddenError("NOT_MESSAGE_OWNER");
    if (text !== null && !message.text) throw new ConflictError("MESSAGE_DELETED");
    if (text !== null && message.sent_at.getTime() + 60_000 <= Date.now()) {
      throw new ConflictError("MESSAGE_EDIT_WINDOW_EXPIRED");
    }
    const outing = await prisma.outings.findUnique({ where: { id: outingId } });
    if (!outing) throw new NotFoundError("Outing");
    const canonical = text === null ? "" : await canonicalizeMentions(text, outing);
    // A tombstone preserves UUID retry deduplication, cursors and read receipts.
    // Recheck closure after mention resolution, before persistence.
    await assertCanChat(outingId, uid);
    const saved = await this.chat.updateMessage(messageId, canonical);
    await emitOutingMessage(outingId, saved, await outingRealtimeUsers(outingId));
    return saved;
  }
}
