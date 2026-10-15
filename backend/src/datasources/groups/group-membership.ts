import { Prisma, type PrismaClient } from "@prisma/client";
import type { GroupMember } from "../../types/groups/group.types.js";

type MembershipDb = PrismaClient | Prisma.TransactionClient;

/**
 * Adds a verified invitee as a member. The group owner is created separately
 * and is never assigned through an invitation.
 */
export async function addInvitedGroupMember(
  db: MembershipDb,
  groupId: string,
  userId: string,
): Promise<{ member: GroupMember; created: boolean }> {
  const where = {
    group_id_user_id: { group_id: groupId, user_id: userId },
  };
  const existing = await db.group_members.findUnique({ where });
  if (existing) return { member: existing, created: false };

  try {
    const member = await db.group_members.create({
      data: { group_id: groupId, user_id: userId, role: "member" },
    });
    return { member, created: true };
  } catch (error) {
    if (
      error instanceof Prisma.PrismaClientKnownRequestError &&
      error.code === "P2002"
    ) {
      const member = await db.group_members.findUnique({ where });
      if (member) return { member, created: false };
    }
    throw error;
  }
}
