import { Prisma } from "@prisma/client";
import { prisma } from "../../config/database.js";
import {
  claimPendingInvitations,
  type InvitationClaimStore,
  type InvitationRecord,
} from "../../services/groups/claim-pending-invitations.js";
import type {
  CreatePendingInvitationInput,
  GroupInvitation,
} from "../../types/groups/group-invitation.types.js";
import { addInvitedGroupMember } from "./group-membership.js";

function isUniqueViolation(error: unknown): boolean {
  return (
    error instanceof Prisma.PrismaClientKnownRequestError &&
    error.code === "P2002"
  );
}

class PrismaInvitationClaimStore implements InvitationClaimStore {
  constructor(private readonly db: Prisma.TransactionClient) {}

  listPendingByPhone(phone: string): Promise<InvitationRecord[]> {
    return this.db.group_invitations.findMany({
      where: { invited_phone: phone, status: "pending" },
      orderBy: { created_at: "asc" },
    });
  }

  getById(id: string): Promise<InvitationRecord | null> {
    return this.db.group_invitations.findUnique({ where: { id } });
  }

  async markExpired(id: string, now: Date): Promise<void> {
    await this.db.group_invitations.update({
      where: { id },
      data: { status: "expired", updated_at: now },
    });
  }

  async markRevoked(id: string, now: Date): Promise<void> {
    await this.db.group_invitations.update({
      where: { id },
      data: { status: "revoked", updated_at: now },
    });
  }

  markAccepted(
    id: string,
    userId: string,
    now: Date,
  ): Promise<InvitationRecord> {
    return this.db.group_invitations.update({
      where: { id },
      data: { status: "accepted", user_id: userId, updated_at: now },
    });
  }

  async groupExists(groupId: string): Promise<boolean> {
    const group = await this.db.groups.findUnique({
      where: { id: groupId },
      select: { id: true },
    });
    return group !== null;
  }

  async addInvitedMember(groupId: string, userId: string): Promise<void> {
    await addInvitedGroupMember(this.db, groupId, userId);
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
      const invitation = await prisma.group_invitations.create({
        data: {
          group_id: input.group_id,
          invited_by_user_id: input.invited_by_user_id,
          invited_phone: input.invited_phone,
          expires_at: input.expires_at,
          status: "pending",
        },
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

  claimForVerifiedPhone(
    userId: string,
    phone: string,
    now = new Date(),
  ): Promise<GroupInvitation[]> {
    return prisma.$transaction((tx) =>
      claimPendingInvitations(new PrismaInvitationClaimStore(tx), {
        userId,
        phone,
        now,
      }),
    );
  }
}
