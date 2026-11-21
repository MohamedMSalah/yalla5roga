import { errorCode, logger } from "../monitoring/logger.js";
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
    logger.warn({ errorCode: errorCode(error) }, "Group audience lookup failed");
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
    logger.warn({ errorCode: errorCode(error) }, "Outing audience lookup failed");
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
  votingEvent?: "outing:voting_tie_detected" | "outing:voting_revote_started" | "outing:voting_round_updated" | "outing:location_confirmed",
  expectedRound?: number,
): Promise<void> {
  const recipients = [...(await outingRealtimeUsers(id)), ...extraUsers];
  emitDataChange({ kind, id }, recipients);
  emitDataChange({ kind: "inbox" }, recipients);
  const io = getChatIo();
  if (!io || !votingEvent || recipients.length === 0) return;
  try {
    const [row] = await prisma.$queryRaw<Array<{
      round_id: string; round_number: number; round_status: string; outing_status: string;
      winning_option_id: string | null; updated_at: Date; option_ids: string[]; tied_option_ids: string[];
    }>>`
      SELECT r.id AS round_id, r.round_number, r.status AS round_status, o.status AS outing_status,
             o.winning_option_id, o.updated_at,
             ARRAY(SELECT option_id FROM outing_voting_round_options
                   WHERE outing_id = o.id AND round_number = r.round_number) AS option_ids,
             ARRAY(SELECT option_id FROM outing_voting_round_options
                   WHERE outing_id = o.id AND round_number = r.round_number AND is_tied) AS tied_option_ids
      FROM outings o JOIN outing_voting_rounds r
        ON r.outing_id = o.id AND r.round_number = o.current_voting_round
      WHERE o.id = ${id}::uuid
    `;
    if (!row || (expectedRound !== undefined && row.round_number !== expectedRound)) return;
    const votingState = row.outing_status === "cancelled" ? "cancelled" :
      row.outing_status === "confirmed" || row.round_status === "confirmed" || row.winning_option_id ? "confirmed" :
      row.outing_status === "voting" && row.round_status === "tie_pending" && row.tied_option_ids.length >= 2 ? "tie_pending" :
      row.round_number > 1 ? "revote_active" : "active";
    if (votingEvent === "outing:voting_tie_detected" && votingState !== "tie_pending") return;
    if (votingEvent === "outing:voting_revote_started" && votingState !== "revote_active") return;
    if (votingEvent === "outing:location_confirmed" && votingState !== "confirmed") return;
    io.to([...new Set(recipients)].map(userRealtimeRoom)).emit(votingEvent, {
      outingId: id, roundId: row.round_id, roundNumber: row.round_number, votingState,
      optionIds: row.option_ids, tiedOptionIds: votingState === "tie_pending" ? row.tied_option_ids : [],
      confirmedOptionId: row.winning_option_id, updatedAt: row.updated_at.toISOString(),
    });
  } catch (error) {
    logger.warn({ errorCode: errorCode(error) }, "Voting update delivery failed");
  }
}
