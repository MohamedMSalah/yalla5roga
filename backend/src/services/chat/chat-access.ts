import type { outing_status } from "@prisma/client";
import { prisma } from "../../config/database.js";
import {
  ConflictError,
  ForbiddenError,
  NotFoundError,
} from "../../utils/errors.js";

/** Sending is allowed only while the outing has not finished or been cancelled. */
const CHAT_OPEN_STATUSES: ReadonlySet<outing_status> = new Set<outing_status>([
  "upcoming",
  "voting",
]);

async function loadOutingForUser(outingId: string, uid: string) {
  const outing = await prisma.outings.findUnique({
    where: { id: outingId },
    select: {
      status: true,
      created_by: true,
      outing_guests: { where: { user_id: uid }, select: { user_id: true } },
    },
  });
  if (!outing) throw new NotFoundError("Outing");
  return outing;
}

/**
 * A participant is the creator or a row in outing_guests.
 * Reading history needs only this check, so finished chats stay readable.
 */
export async function assertChatParticipant(outingId: string, uid: string) {
  const outing = await loadOutingForUser(outingId, uid);
  const isParticipant =
    outing.created_by === uid || outing.outing_guests.length > 0;
  if (!isParticipant) throw new ForbiddenError("NOT_A_PARTICIPANT");
  return outing;
}

/** Participant check plus the "chat is still open" rule used when sending. */
export async function assertCanChat(outingId: string, uid: string) {
  const outing = await assertChatParticipant(outingId, uid);
  if (!CHAT_OPEN_STATUSES.has(outing.status)) {
    throw new ConflictError("CHAT_CLOSED");
  }
}
