import type { Server, Socket } from "socket.io";
import { z } from "zod";
import { assertChatParticipant } from "../services/chat/chat-access.js";
import { outingChatRoom } from "./rooms.js";

const outingIdSchema = z.object({
  outingId: z.uuid(),
});

type Ack = (payload: {
  ok: boolean;
  error?: string;
  room?: string;
}) => void;

function safeAck(ack: unknown, payload: Parameters<Ack>[0]) {
  if (typeof ack === "function") {
    (ack as Ack)(payload);
  }
}

function uidOf(socket: Socket): string | null {
  const uid = socket.data?.uid;
  return typeof uid === "string" && uid.length > 0 ? uid : null;
}

/**
 * Registers outing chat room join/leave handlers.
 * Membership is always checked server-side; clients cannot self-authorize rooms.
 */
export function registerChatGateway(io: Server): void {
  io.on("connection", (socket) => {
    socket.on("outing:join", async (raw: unknown, ack?: unknown) => {
      const uid = uidOf(socket);
      if (!uid) {
        safeAck(ack, { ok: false, error: "UNAUTHORIZED" });
        return;
      }

      const parsed = outingIdSchema.safeParse(raw);
      if (!parsed.success) {
        safeAck(ack, { ok: false, error: "INVALID_OUTING_ID" });
        return;
      }

      const { outingId } = parsed.data;
      try {
        await assertChatParticipant(outingId, uid);
      } catch {
        safeAck(ack, { ok: false, error: "FORBIDDEN" });
        return;
      }

      const room = outingChatRoom(outingId);
      await socket.join(room);
      safeAck(ack, { ok: true, room });
    });

    socket.on("outing:leave", async (raw: unknown, ack?: unknown) => {
      const parsed = outingIdSchema.safeParse(raw);
      if (!parsed.success) {
        safeAck(ack, { ok: false, error: "INVALID_OUTING_ID" });
        return;
      }

      const room = outingChatRoom(parsed.data.outingId);
      await socket.leave(room);
      safeAck(ack, { ok: true, room });
    });
  });
}
