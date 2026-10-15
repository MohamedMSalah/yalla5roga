import type {
  CreatePendingInvitationInput,
  GroupInvitation,
} from "../../types/groups/group-invitation.types.js";

export type CreatePendingInvitationResult = {
  invitation: GroupInvitation;
  created: boolean;
};

export interface IGroupInvitationRepository {
  findPending(
    groupId: string,
    phone: string,
  ): Promise<GroupInvitation | null>;
  createPending(
    input: CreatePendingInvitationInput,
  ): Promise<CreatePendingInvitationResult>;
  claimForVerifiedPhone(
    userId: string,
    phone: string,
    now?: Date,
  ): Promise<GroupInvitation[]>;
}
