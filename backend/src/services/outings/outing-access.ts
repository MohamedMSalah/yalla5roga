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
