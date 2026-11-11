import type { Server } from "socket.io";
import type { ChatMessage, ChatRead } from "../types/chat/chat.types.js";
import { outingChatRoom, userRealtimeRoom } from "./rooms.js";

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
    sender: message.sender,
    avatar: message.avatar,
    text: message.text,
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
 * Fan-out after REST persistence. Delivery only â€” never persists.
 * Clients dedupe by message `id`.
 */
export async function emitOutingMessage(
  outingId: string, message: ChatMessage, audience: readonly string[],
): Promise<void> {
  if (!io || audience.length === 0) return;
  const authorized = new Set(audience);
  // Room membership can outlive a removed group/outing membership.
  const payload = serializeChatMessage(message);
  try {
    const sockets = await io.in(outingChatRoom(outingId)).fetchSockets();
    for (const socket of sockets) {
      if (authorized.has(socket.data.uid)) socket.emit("outing:message", payload);
    }
  } catch (error) {
    console.error("[realtime] chat delivery failed", error);
  }
}

export async function emitOutingRead(outingId: string, read: ChatRead): Promise<void> {
  if (!io) return;
  try {
    const { outingRealtimeUsers } = await import("./data-changes.js");
    const audience = new Set(await outingRealtimeUsers(outingId));
    const sockets = await io.in(outingChatRoom(outingId)).fetchSockets();
    for (const socket of sockets) {
      if (audience.has(socket.data.uid)) socket.emit("outing:read", serializeChatRead(read));
      else await socket.leave(outingChatRoom(outingId));
    }
  } catch (error) {
    console.error("[realtime] read delivery failed", error);
  }
}


/** Invalidates the roster for currently authorized participants. */
export function emitOutingArrivalChanged(outingId: string, participantIds: string[]): void {
  if (participantIds.length === 0) return;
  io?.to(participantIds.map(userRealtimeRoom)).emit("outing:arrival_changed", { outing_id: outingId });
}
