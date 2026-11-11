import type { Server } from "socket.io";
import { z } from "zod";
import { GroupRepository } from "../repositories/groups/group.repository.js";
import { assertGroupMember } from "../services/groups/group-access.js";
import { groupRealtimeRoom } from "./rooms.js";

const groupIdSchema = z.object({ groupId: z.uuid() });

/** Uses the existing authenticated transport; room names never grant access. */
export function registerGroupGateway(
  io: Server,
  authorize = (id: string, uid: string) => assertGroupMember(new GroupRepository(), id, uid),
): void {
  io.on("connection", (socket) => {
    for (const action of ["join", "leave"] as const) {
      socket.on(`group:${action}`, async (raw: unknown, ack: unknown) => {
        const respond = (payload: object) => { if (typeof ack === "function") ack(payload); };
        const parsed = groupIdSchema.safeParse(raw);
        if (!parsed.success) return respond({ ok: false, error: "INVALID_GROUP_ID" });
        if (!socket.data.uid) return respond({ ok: false, error: "UNAUTHORIZED" });
        const room = groupRealtimeRoom(parsed.data.groupId);
        try {
          if (action === "join") {
            await authorize(parsed.data.groupId, socket.data.uid);
            if (!socket.connected) return;
            await socket.join(room);
          } else {
            await socket.leave(room);
          }
          respond({ ok: true, room });
        } catch {
          await socket.leave(room);
          respond({ ok: false, error: "FORBIDDEN" });
        }
      });
    }
  });
}
