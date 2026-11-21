import type { Server } from "socket.io";
import { observeSocketAck } from "../monitoring/socket.js";
import { increment } from "../monitoring/metrics.js";
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
    const joins = new Map<string, object>();
    socket.on("disconnect", () => joins.clear());
    for (const action of ["join", "leave"] as const) {
      socket.on(`group:${action}`, async (raw: unknown, ack: unknown) => {
        const reply = observeSocketAck(`group:${action}`, ack);
        const respond = (payload: object) => reply?.(payload);
        const parsed = groupIdSchema.safeParse(raw);
        if (!parsed.success) return respond({ ok: false, error: "INVALID_GROUP_ID" });
        if (!socket.data.uid) return respond({ ok: false, error: "UNAUTHORIZED" });
        const room = groupRealtimeRoom(parsed.data.groupId);
        const id = parsed.data.groupId;
        const intent = {};
        if (action === "join") {
          if (joins.has(id)) increment("socket_overlapping_joins_total", { event: "group:join" });
          joins.set(id, intent);
        } else joins.delete(id);
        try {
          if (action === "join") {
            await authorize(parsed.data.groupId, socket.data.uid);
            if (!socket.connected || joins.get(id) !== intent) return;
            await socket.join(room);
            if (!socket.connected || joins.get(id) !== intent) {
              if (!joins.has(id)) await socket.leave(room);
              return;
            }
            joins.delete(id);
          } else {
            await socket.leave(room);
          }
          respond({ ok: true, room });
        } catch {
          if (!socket.connected || (action === "join" && joins.get(id) !== intent)) return;
          joins.delete(id);
          await socket.leave(room);
          respond({ ok: false, error: "FORBIDDEN" });
        }
      });
    }
  });
}
