export type InvitationStatus = "pending" | "accepted" | "expired" | "revoked";

export type InvitationRecord = {
  id: string;
  group_id: string;
  invited_by_user_id: string;
  invited_phone: string;
  user_id: string | null;
  status: InvitationStatus;
  expires_at: Date;
  created_at: Date;
  updated_at: Date;
};

export interface InvitationClaimStore {
  listPendingByPhone(phone: string): Promise<InvitationRecord[]>;
  getById(id: string): Promise<InvitationRecord | null>;
  markExpired(id: string, now: Date): Promise<void>;
  markRevoked(id: string, now: Date): Promise<void>;
  markAccepted(
    id: string,
    userId: string,
    now: Date,
  ): Promise<InvitationRecord>;
  groupExists(groupId: string): Promise<boolean>;
  addInvitedMember(groupId: string, userId: string): Promise<void>;
}

/**
 * Claims every valid pending invitation for a verified phone.
 * Callers run this inside a transaction so a later failure undoes every write.
 */
export async function claimPendingInvitations(
  store: InvitationClaimStore,
  input: { userId: string; phone: string; now: Date },
): Promise<InvitationRecord[]> {
  const pending = await store.listPendingByPhone(input.phone);
  const accepted: InvitationRecord[] = [];

  for (const invitation of pending) {
    const current = await store.getById(invitation.id);
    if (!current || current.status !== "pending") continue;
    if (current.invited_phone !== input.phone) continue;

    if (current.expires_at.getTime() <= input.now.getTime()) {
      await store.markExpired(current.id, input.now);
      continue;
    }

    if (!(await store.groupExists(current.group_id))) {
      await store.markRevoked(current.id, input.now);
      continue;
    }

    await store.addInvitedMember(current.group_id, input.userId);
    accepted.push(
      await store.markAccepted(current.id, input.userId, input.now),
    );
  }

  return accepted;
}
