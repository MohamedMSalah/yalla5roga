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
export async function listEligibleVoterIds(outing: Outing): Promise<string[]> {
  const ids = new Set<string>([outing.created_by]);

  const members = await prisma.outing_guests.findMany({
    where: { outing_id: outing.id, status: "accepted" },
    select: { user_id: true },
  });
  for (const member of members) ids.add(member.user_id);

  if (outing.group_id) {
    const groupMembers = await prisma.group_members.findMany({
      where: { group_id: outing.group_id },
      select: { user_id: true },
    });
    for (const member of groupMembers) ids.add(member.user_id);
  }

  return [...ids];
}

export async function assertEligibleVoter(
  outing: Outing,
  userId: string,
): Promise<void> {
  const eligible = await listEligibleVoterIds(outing);
  if (!eligible.includes(userId)) {
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
