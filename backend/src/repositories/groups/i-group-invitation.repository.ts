import type {
  CreatePendingInvitationInput,
  GroupInvitation,
} from "../../types/groups/group-invitation.types.js";

export type CreatePendingInvitationResult = {
  invitation: GroupInvitation;
  created: boolean;
};

export interface IGroupInvitationRepository {
  findById(id: string): Promise<GroupInvitation | null>;
  findPending(
    groupId: string,
    phone: string,
    now?: Date,
  ): Promise<GroupInvitation | null>;
  createPending(
    input: CreatePendingInvitationInput,
    now?: Date,
  ): Promise<CreatePendingInvitationResult>;
  claimForVerifiedPhone(
    userId: string,
    phone: string,
    now?: Date,
  ): Promise<GroupInvitation[]>;
  /**
   * Accept a pending invitation — creates a group_members row and
   * transitions the invitation to `accepted`.
   */
  accept(
    invitationId: string,
    userId: string,
    now?: Date,
  ): Promise<GroupInvitation | null>;
  /**
   * Decline a pending invitation — transitions the invitation to `declined`.
   * The record is preserved but the invitee is not added as a member.
   */
  decline(
    invitationId: string,
    userId: string,
    now?: Date,
  ): Promise<GroupInvitation | null>;
  /**
   * List all pending invitations for a given user.
   */
  listPendingForUser(userId: string): Promise<GroupInvitation[]>;
}
