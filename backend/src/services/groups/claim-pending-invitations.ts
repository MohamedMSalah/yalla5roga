export type InvitationStatus =
  | "pending"
  | "accepted"
  | "declined"
  | "expired"
  | "revoked";

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
  activate(
    pending: InvitationRecord[],
    userId: string,
    now: Date,
  ): Promise<InvitationRecord[]>;
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
  if (pending.length === 0) return [];
  return store.activate(pending, input.userId, input.now);
}
