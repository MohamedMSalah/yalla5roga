import { prisma } from "../../config/database.js";
import type { Outing } from "../../types/outings/outing.types.js";
import { ForbiddenError, NotFoundError } from "../../utils/errors.js";

/**
 * Loads an outing and requires the caller to be `created_by`.
 * Used for update/delete, guest management, and vote-option mutations.
 */
export async function assertOutingCreator(
  outingId: string,
  callerUid: string,
): Promise<Outing> {
  const outing = await prisma.outings.findUnique({ where: { id: outingId } });
  if (!outing) throw new NotFoundError("Outing");
  if (outing.created_by !== callerUid) {
    throw new ForbiddenError("Only the outing creator can perform this action");
  }
  return outing;
}

/**
 * Same rule when the outing row is already loaded.
 */
export function assertIsOutingCreator(outing: Outing, callerUid: string): void {
  if (outing.created_by !== callerUid) {
    throw new ForbiddenError("Only the outing creator can perform this action");
  }
}

/** Read access is independent of whether chat or voting is open. */
export async function assertOutingAccess(outingId: string, uid: string): Promise<Outing> {
  const outing = await prisma.outings.findUnique({ where: { id: outingId } });
  if (!outing) throw new NotFoundError("Outing");
  if (outing.created_by === uid) return outing;
  const [member, invitation] = await Promise.all([
    outing.group_id ? prisma.group_members.findUnique({ where: {
      group_id_user_id: { group_id: outing.group_id, user_id: uid },
    } }) : null,
    prisma.outing_guests.findFirst({ where: {
      outing_id: outingId, user_id: uid, status: { in: ["pending", "accepted"] },
    } }),
  ]);
  if (!member && !invitation) throw new ForbiddenError("Only outing participants can access this outing");
  return outing;
}
