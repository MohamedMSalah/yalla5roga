import type { group_invitations } from "@prisma/client";

export type GroupInvitation = group_invitations;

export type CreatePendingInvitationInput = {
  group_id: string;
  invited_by_user_id: string;
  invited_phone: string;
  expires_at: Date;
};
