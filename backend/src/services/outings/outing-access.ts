import { measure } from "../../monitoring/context.js";
import { prisma } from "../../config/database.js";
import type { Prisma } from "@prisma/client";
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
export function assertOutingAccess(outingId: string, uid: string): Promise<Outing> {
  return measure("authorizationMs", async () => {
    const [result] = await prisma.$queryRaw<(Outing & { can_access: boolean })[]>`
      SELECT o.*, (
        o.created_by = ${uid}
        OR EXISTS (SELECT 1 FROM group_members m WHERE m.group_id = o.group_id AND m.user_id = ${uid})
        OR EXISTS (SELECT 1 FROM outing_guests g WHERE g.outing_id = o.id
          AND g.user_id = ${uid} AND g.status IN ('pending', 'accepted'))
      ) AS can_access
      FROM outings o WHERE o.id = ${outingId}::uuid
    `;
    if (!result) throw new NotFoundError("Outing");
    const { can_access, ...outing } = result;
    if (!can_access) throw new ForbiddenError("Only outing participants can access this outing");
    return outing;
  });
}

export async function hasOutingAccess(outing: Outing, uid: string, db: Prisma.TransactionClient = prisma): Promise<boolean> {
  if (outing.created_by === uid) return true;
  const [member, invitation] = await Promise.all([
    outing.group_id ? db.group_members.findUnique({ where: {
      group_id_user_id: { group_id: outing.group_id, user_id: uid },
    } }) : null,
    db.outing_guests.findFirst({ where: {
      outing_id: outing.id, user_id: uid, status: { in: ["pending", "accepted"] },
    } }),
  ]);
  return Boolean(member || invitation);
}
