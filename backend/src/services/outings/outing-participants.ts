import type { Prisma } from "@prisma/client";
import { prisma } from "../../config/database.js";
import type { Outing } from "../../types/outings/outing.types.js";
import { ForbiddenError } from "../../utils/errors.js";

/**
 * Eligible voters / participants (product scenarios):
 * - Outing Owner (created_by)
 * - Accepted Members (outing_guests.status = accepted)
 * - Group members when the outing belongs to a group (documented Member path)
 *
 * Pending invitations are never eligible. Attendance does not affect eligibility.
 */
export async function listEligibleVoterIds(outing: Outing, db: Prisma.TransactionClient = prisma): Promise<string[]> {
  const rows = await db.$queryRaw<{ user_id: string }[]>`
    SELECT ${outing.created_by}::varchar AS user_id
    UNION
    SELECT user_id FROM outing_guests
    WHERE outing_id = ${outing.id}::uuid AND status = 'accepted'
    UNION
    SELECT user_id FROM group_members WHERE group_id = ${outing.group_id}::uuid
  `;
  return rows.map(({ user_id }) => user_id);
}

export async function assertEligibleVoter(
  outing: Outing,
  userId: string,
): Promise<void> {
  if (outing.created_by === userId) return;
  const eligible = await prisma.outings.findUnique({
    where: {
      id: outing.id,
      OR: [
        { outing_guests: { some: { user_id: userId, status: "accepted" } } },
        { groups: { group_members: { some: { user_id: userId } } } },
      ],
    },
    select: { id: true },
  });
  if (!eligible) {
    throw new ForbiddenError("Only outing members can vote");
  }
}

export async function assertOutingParticipant(
  outing: Outing,
  userId: string,
): Promise<void> {
  await assertEligibleVoter(outing, userId);
}

/** Participant ids used for fan-out notifications (owner + accepted members + group). */
export async function listParticipantIds(outing: Outing): Promise<string[]> {
  return listEligibleVoterIds(outing);
}
