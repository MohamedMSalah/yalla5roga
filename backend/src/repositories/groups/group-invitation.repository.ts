import { GroupInvitationDatasource } from "../../datasources/groups/group-invitation.datasource.js";
import type {
  CreatePendingInvitationInput,
  GroupInvitation,
} from "../../types/groups/group-invitation.types.js";
import type {
  CreatePendingInvitationResult,
  IGroupInvitationRepository,
} from "./i-group-invitation.repository.js";

export class GroupInvitationRepository implements IGroupInvitationRepository {
  constructor(
    private readonly datasource = new GroupInvitationDatasource(),
  ) {}

  findPending(groupId: string, phone: string): Promise<GroupInvitation | null> {
    return this.datasource.findPending(groupId, phone);
  }

  createPending(
    input: CreatePendingInvitationInput,
  ): Promise<CreatePendingInvitationResult> {
    return this.datasource.createPending(input);
  }

  claimForVerifiedPhone(
    userId: string,
    phone: string,
    now?: Date,
  ): Promise<GroupInvitation[]> {
    return this.datasource.claimForVerifiedPhone(userId, phone, now);
  }
}
