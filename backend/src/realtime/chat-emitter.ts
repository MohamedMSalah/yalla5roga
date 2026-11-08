import type { Server } from "socket.io";
import type { ChatMessage, ChatRead } from "../types/chat/chat.types.js";
import { outingChatRoom } from "./rooms.js";

let io: Server | null = null;

export function bindChatEmitter(server: Server): void {
  io = server;
}

export function getChatIo(): Server | null {
  return io;
}

/** JSON-safe message payload mirroring REST Prisma rows. */
export function serializeChatMessage(message: ChatMessage) {
  return {
    id: message.id,
    outing_id: message.outing_id,
    sender_id: message.sender_id,
    text: message.text,
    delivery_status: message.delivery_status,
    sent_at:
      message.sent_at instanceof Date
        ? message.sent_at.toISOString()
        : message.sent_at,
    client_message_id: message.client_message_id,
  };
}

export function serializeChatRead(read: ChatRead) {
  return {
    outing_id: read.outing_id,
    user_id: read.user_id,
    last_read_at:
      read.last_read_at instanceof Date
        ? read.last_read_at.toISOString()
        : read.last_read_at,
  };
}

/**
 * Fan-out after REST persistence. Delivery only — never persists.
 * Clients dedupe by message `id`.
 */
export function emitOutingMessage(outingId: string, message: ChatMessage): void {
  if (!io) return;
  io.to(outingChatRoom(outingId)).emit(
    "outing:message",
    serializeChatMessage(message),
  );
}

export function emitOutingRead(outingId: string, read: ChatRead): void {
  if (!io) return;
  io.to(outingChatRoom(outingId)).emit("outing:read", serializeChatRead(read));
}
