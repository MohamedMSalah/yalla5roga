import { prisma } from "../config/database.js";
import { getChatIo } from "./chat-emitter.js";
import { groupRealtimeRoom, userRealtimeRoom } from "./rooms.js";
import { randomUUID } from "node:crypto";

export type DataChange =
  | { kind: "group" | "membership" | "outing" | "outings"; id: string }
  | { kind: "attendance"; id: string; payload: { user_id: string; status: string; updated_at: string };
    }
  | { kind: "profile" | "inbox" };

const epoch = randomUUID();
let sequence = 0;
let recoveryFloor = 0;
type Invalidation = Exclude<DataChange, { kind: "attendance" }>;
const journal: { sequence: number; at: number; change: Invalidation; users: Set<string>;
}[] = [];

/** Bounded invalidations for this single-process deployment; never domain data. */
export function reconcileDataChanges(uid: string, cursor: unknown) {
  const c = cursor as { epoch?: unknown; sequence?: unknown } | null;
  const valid = c?.epoch === epoch && typeof c.sequence === "number" &&
    Number.isInteger(c.sequence) && c.sequence >= recoveryFloor && c.sequence <= sequence &&
    (c.sequence === sequence || (journal.length > 0 && c.sequence >= journal[0]!.sequence - 1 &&
      journal[0]!.at > Date.now() - 600_000));
  return {
    ok: true, reset: !valid, cursor: { epoch, sequence },
    // Replay identifiers only: membership may have been revoked since a write.
    // REST rechecks current access before returning any domain payload.
    changes: valid ? journal.filter(
            (e) => e.sequence > (c!.sequence as number) && e.users.has(uid),
          ).map((e) => ({
      ...e.change,
      cursor: { epoch, sequence: e.sequence },
    })) : [],
  };
}

export function emitDataChange(change: DataChange, users: readonly string[],
): void {
  sequence++;
  const invalidation: Invalidation = change.kind === "attendance"
    ? { kind: "outing", id: change.id } : change;
  journal.push({ sequence, at: Date.now(), change: invalidation, users: new Set(users),
  });
  while (journal.length > 512 || journal[0]!.at < Date.now() - 600_000) journal.shift();
  const rooms = [...new Set(users)].filter(Boolean).map(userRealtimeRoom);
  if (rooms.length) getChatIo()?.to(rooms).emit("data:changed", { ...change, cursor: { epoch, sequence } });
}

export async function groupRealtimeUsers(id: string): Promise<string[]> {
  if (!getChatIo()) return [];
  try {
    const rows = await prisma.group_members.findMany({
      where: { group_id: id },
      select: { user_id: true },
    });
    return rows.map((row) => row.user_id);
  } catch (error) {
    recoveryFloor = ++sequence;
    console.error("[realtime] failed to resolve group audience", error);
    return [];
  }
}

export async function outingRealtimeUsers(id: string, includePending = true,
): Promise<string[]> {
  if (!getChatIo()) return [];
  try {
    const outing = await prisma.outings.findUnique({
      where: { id },
      select: {
        created_by: true,
        outing_guests: {
          where: { status: { in: includePending ? ["pending", "accepted"] : ["accepted"],
            },
          },
          select: { user_id: true },
        },
        groups: { select: { group_members: { select: { user_id: true } } } },
      },
    });
    if (!outing) return [];
    return [
      outing.created_by,
      ...outing.outing_guests.map((row) => row.user_id),
      ...(outing.groups?.group_members.map((row) => row.user_id) ?? []),
    ];
  } catch (error) {
    recoveryFloor = ++sequence;
    console.error("[realtime] failed to resolve outing audience", error);
    return [];
  }
}

export async function publishGroupChange(
  id: string, kind: "group" | "membership", extraUsers: string[] = [],
): Promise<void> {
  const currentUsers = await groupRealtimeUsers(id);
  emitDataChange({ kind, id }, [...currentUsers, ...extraUsers]);
  emitDataChange({ kind: "inbox" }, [...currentUsers, ...extraUsers]);
  if (kind === "membership") {
    // Revoked users still receive their account-level invalidation, but lose
    // the group subscription immediately on every connected device.
    const allowed = new Set(currentUsers);
    const sockets = await getChatIo()?.in(groupRealtimeRoom(id)).fetchSockets();
    await Promise.all((sockets ?? []).filter((socket) => !allowed.has(socket.data.uid))
      .map((socket) => socket.leave(groupRealtimeRoom(id))),
    );
  }
}

export async function publishOutingChange(
  id: string, kind: "outing" | "outings" = "outing", extraUsers: string[] = [],
  votingEvent: "outing:voting_tie_detected" | "outing:voting_revote_started" | "outing:voting_round_updated" | "outing:location_confirmed" = "outing:voting_round_updated",
): Promise<void> {
  const recipients = [...(await outingRealtimeUsers(id)), ...extraUsers];
  emitDataChange({ kind, id }, recipients);
  emitDataChange({ kind: "inbox" }, recipients);
  if (!getChatIo() || recipients.length === 0) return;
  const outing = await prisma.outings.findUnique({ where: { id }, select: { current_voting_round: true, vote_closed_at: true, winning_option_id: true, status: true, updated_at: true } });
  if (outing) {
    const round = await prisma.outing_voting_rounds.findUnique({ where: { outing_id_round_number: { outing_id: id, round_number: outing.current_voting_round } }, include: { options: { where: { is_tied: true }, select: { option_id: true } } } });
    const votingState = outing.status === "cancelled" ? "cancelled" : outing.winning_option_id ? "confirmed" : outing.vote_closed_at ? "tie_pending" : outing.current_voting_round > 1 ? "revote_active" : "active";
    const event = votingEvent;
    const payload = { outingId: id, roundId: round?.id, roundNumber: outing.current_voting_round, votingState, tiedOptionIds: votingState === "tie_pending" ? round?.options.map(o => o.option_id) ?? [] : [], confirmedOptionId: outing.winning_option_id, updatedAt: outing.updated_at.toISOString() };
    getChatIo()?.to([...new Set(recipients)].map(userRealtimeRoom)).emit(event, payload);
  }
}
