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
}
