import { Prisma } from "@prisma/client";
import { prisma } from "../../config/database.js";
import { ForbiddenError, NotFoundError } from "../../utils/errors.js";
import {
  claimPendingInvitations,
  type InvitationClaimStore,
  type InvitationRecord,
} from "../../services/groups/claim-pending-invitations.js";
import type {
  CreatePendingInvitationInput,
  GroupInvitation,
} from "../../types/groups/group-invitation.types.js";

function isUniqueViolation(error: unknown): boolean {
  return (
    error instanceof Prisma.PrismaClientKnownRequestError &&
    error.code === "P2002"
  );
}

export class PrismaInvitationClaimStore implements InvitationClaimStore {
  constructor(private readonly db: Prisma.TransactionClient) {}

  listPendingByPhone(phone: string): Promise<InvitationRecord[]> {
    return this.db.$queryRaw<InvitationRecord[]>`
      SELECT * FROM group_invitations
      WHERE invited_phone = ${phone} AND status = 'pending'
      ORDER BY created_at, id
      FOR UPDATE
    `;
  }

  async activate(
    pending: InvitationRecord[],
    userId: string,
    now: Date,
  ): Promise<InvitationRecord[]> {
    await this.db.group_members.createMany({
      data: pending.map(row => ({ group_id: row.group_id, user_id: userId, role: "member" })),
      skipDuplicates: true,
    });
    return this.db.group_invitations.updateManyAndReturn({
      where: { id: { in: pending.map(row => row.id) } },
      data: { status: "accepted", user_id: userId, updated_at: now },
    });
  }
}

export class GroupInvitationDatasource {
  findPending(
    groupId: string,
    phone: string,
  ): Promise<GroupInvitation | null> {
    return prisma.group_invitations.findFirst({
      where: {
        group_id: groupId,
        invited_phone: phone,
        status: "pending",
      },
    });
  }

  async createPending(
    input: CreatePendingInvitationInput,
  ): Promise<{ invitation: GroupInvitation; created: boolean }> {
    try {
      const invitation = await prisma.$transaction(async (tx) => {
        const rows = await tx.$queryRaw<Array<{ id: string }>>`
          SELECT id FROM groups WHERE id = ${input.group_id}::uuid FOR UPDATE
        `;
        if (!rows.length) throw new NotFoundError("Group");
        const inviter = await tx.group_members.findUnique({
          where: { group_id_user_id: { group_id: input.group_id, user_id: input.invited_by_user_id } },
        });
        if (!inviter) throw new ForbiddenError("Only group members can invite");
        return tx.group_invitations.create({ data: { ...input, status: "pending" } });
      });
      return { invitation, created: true };
    } catch (error) {
      if (!isUniqueViolation(error)) throw error;

      const invitation = await this.findPending(
        input.group_id,
        input.invited_phone,
      );
      if (!invitation) throw error;
      return { invitation, created: false };
    }
  }

  async revokePending(groupId: string, id: string): Promise<GroupInvitation | null> {
    const [revoked] = await prisma.group_invitations.updateManyAndReturn({
      where: { id, group_id: groupId, status: "pending" },
      data: { status: "revoked" },
    });
    return revoked ?? null;
  }

  async claimForVerifiedPhone(
    userId: string,
    phone: string,
    now = new Date(),
  ): Promise<GroupInvitation[]> {
    const claim = () => prisma.$transaction(async (tx) => {
      const users = await tx.$queryRaw<Array<{ id: string }>>`
        SELECT id FROM users WHERE id = ${userId} AND phone = ${phone} FOR UPDATE
      `;
      if (users.length === 0) return [];
      return claimPendingInvitations(new PrismaInvitationClaimStore(tx), {
        userId,
        phone,
        now,
      });
    });
    try {
      return await claim();
    } catch (error) {
      // A concurrent group deletion can lock the parent before its cascade.
      if (!(error instanceof Prisma.PrismaClientKnownRequestError) ||
          !(error.code === "P2034" ||
            (error.code === "P2010" && error.meta?.code === "40P01"))) throw error;
      return claim();
    }
  }
}
