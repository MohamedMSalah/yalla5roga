import type { Prisma, PrismaClient } from "@prisma/client";
import type { GroupMember } from "../../types/groups/group.types.js";
import { ForbiddenError, NotFoundError } from "../../utils/errors.js";

type MembershipDb = PrismaClient | Prisma.TransactionClient;

/**
 * Adds a verified invitee as a member. The group owner is created separately
 * and is never assigned through an invitation.
 */
export async function addInvitedGroupMember(
  db: MembershipDb,
  groupId: string,
  userId: string,
  callerId?: string,
): Promise<{ member: GroupMember; created: boolean }> {
  const add = async (tx: Prisma.TransactionClient) => {
  const rows = await tx.$queryRaw<Array<{ id: string }>>`
    SELECT id FROM groups WHERE id = ${groupId}::uuid FOR UPDATE
  `;
  if (!rows.length) throw new NotFoundError("Group");
  if (callerId && !await tx.group_members.findUnique({
    where: { group_id_user_id: { group_id: groupId, user_id: callerId } },
  })) throw new ForbiddenError("Only group members can invite");
  const where = {
    group_id_user_id: { group_id: groupId, user_id: userId },
  };
  const { count } = await tx.group_members.createMany({
    data: { group_id: groupId, user_id: userId, role: "member" },
    skipDuplicates: true,
  });
  const member = await tx.group_members.findUniqueOrThrow({ where });
  const user = await tx.users.findUniqueOrThrow({ where: { id: userId }, select: { phone: true } });
  await tx.group_invitations.updateMany({
    where: { group_id: groupId, invited_phone: user.phone, status: "pending" },
    data: { status: "accepted", user_id: userId },
  });
  return { member, created: count === 1 };
  };
  return "$transaction" in db ? db.$transaction(add) : add(db);
}
