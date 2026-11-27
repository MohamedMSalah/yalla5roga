import type { Server } from "socket.io";
import { z } from "zod";
import { observeSocketAck } from "../../monitoring/socket.js";
import { meetupRealtimeRoom } from "../../realtime/rooms.js";
import { MeetupSubscriptionAuthorizationPolicy } from "./meetup-subscription-authorization.policy.js";

const version = z.number().int().positive();
const session = z.strictObject({ sessionId: z.uuid() });
const input = session.extend({ inputVersion: version });
export const meetupChange = z.discriminatedUnion("changeType", [
  input.extend({ changeType: z.enum(["SESSION_UPDATED", "SESSION_EXPIRED", "READINESS_CHANGED", "PREFERENCES_CHANGED"]) }),
  input.extend({ changeType: z.enum(["RESULTS_INVALIDATED", "CALCULATION_COMPLETED"]), calculationAttempt: version }),
]);
type MeetupChange = z.infer<typeof meetupChange>;

const events = {
  SESSION_UPDATED: "smart_meetup:session_updated",
  SESSION_EXPIRED: "smart_meetup:session_expired",
  READINESS_CHANGED: "smart_meetup:readiness_changed",
  PREFERENCES_CHANGED: "smart_meetup:preferences_changed",
  RESULTS_INVALIDATED: "smart_meetup:results_invalidated",
  CALCULATION_COMPLETED: "smart_meetup:calculation_completed",
} as const;
const revoked = "smart_meetup:subscription_revoked";

export class SmartMeetupRealtimeService {
  constructor(private readonly policy = new MeetupSubscriptionAuthorizationPolicy()) {}

  register(io: Server): void {
    io.on("connection", socket => {
      const pending = new Map<string, object>();
      socket.on("disconnect", () => pending.clear());
      socket.on("meetup:join", async (raw: unknown, ack: unknown) => {
        const reply = observeSocketAck("meetup:join", ack);
        const parsed = session.safeParse(raw);
        if (!parsed.success) return reply?.({ ok: false, error: "INVALID_SESSION_ID" });
        if (typeof socket.data.uid !== "string") return reply?.({ ok: false, error: "UNAUTHORIZED" });
        const id = parsed.data.sessionId.toLowerCase();
        const room = meetupRealtimeRoom(id);
        const intent = {};
        pending.set(id, intent);
        const current = () => socket.connected && pending.get(id) === intent;
        const authorize = async () => {
          const state = await this.policy.current(id);
          if (!this.policy.permits(state, socket.data.uid)) return { ok: false, error: "FORBIDDEN" };
          if (!state.active) return { ok: false, error: "CLOSED" };
          return { ok: true, inputVersion: state.input_version };
        };
        try {
          let response = await authorize();
          if (!current()) return;
          if (response.ok) {
            await socket.join(room);
            if (!current()) return;
            // Recheck after joining so a commit concurrent with the first check
            // cannot leave a stale subscription behind.
            response = await authorize();
            if (!current()) return;
          }
          if (!response.ok) await socket.leave(room);
          if (current()) reply?.(response);
        } catch {
          if (!current()) return;
          await socket.leave(room);
          if (current()) reply?.({ ok: false, error: "SUBSCRIPTION_FAILED" });
        } finally {
          if (pending.get(id) === intent) pending.delete(id);
        }
      });
      socket.on("meetup:leave", async (raw: unknown, ack: unknown) => {
        const reply = observeSocketAck("meetup:leave", ack);
        const parsed = session.safeParse(raw);
        if (!parsed.success) return reply?.({ ok: false, error: "INVALID_SESSION_ID" });
        const id = parsed.data.sessionId.toLowerCase();
        pending.delete(id);
        await socket.leave(meetupRealtimeRoom(id));
        reply?.({ ok: true });
      });
    });
  }

  async deliver(io: Server, event: MeetupChange): Promise<void> {
    const { sessionId, inputVersion, changeType } = event;
    const room = meetupRealtimeRoom(sessionId);
    const ids = [...(io.sockets.adapter.rooms.get(room) ?? [])];
    if (!ids.length) return;
    const state = await this.policy.current(sessionId);
    const closed = changeType === "SESSION_EXPIRED" || changeType === "SESSION_UPDATED";
    const current = state?.input_version === inputVersion &&
      (closed ? state.status !== "ACTIVE" : state.active) &&
      (changeType !== "CALCULATION_COMPLETED" ||
        (state.attempt === event.calculationAttempt && state.calculation_status !== "STALE"));
    await Promise.all(ids.map(async id => {
      const socket = io.sockets.sockets.get(id);
      if (!socket?.rooms.has(room)) return;
      if (!this.policy.permits(state, socket.data.uid)) {
        socket.emit(revoked, { sessionId });
        await socket.leave(room);
      } else if (current) {
        socket.emit(events[changeType], event);
        if (closed) await socket.leave(room);
      }
    }));
  }
}
