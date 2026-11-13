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

  findById(id: string): Promise<GroupInvitation | null> {
    return this.datasource.findById(id);
  }

  findPending(groupId: string, phone: string, now?: Date): Promise<GroupInvitation | null> {
    return this.datasource.findPending(groupId, phone);
  }

  createPending(
    input: CreatePendingInvitationInput,
    now?: Date,
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

  revokePending(groupId: string, id: string): Promise<GroupInvitation | null> {
    return this.datasource.revokePending(groupId, id);
  }

  accept(
    invitationId: string,
    userId: string,
    now?: Date,
  ): Promise<GroupInvitation | null> {
    return this.datasource.accept(invitationId, userId, now);
  }

  decline(
    invitationId: string,
    userId: string,
    now?: Date,
  ): Promise<GroupInvitation | null> {
    return this.datasource.decline(invitationId, userId, now);
  }

  listPendingForUser(userId: string): Promise<GroupInvitation[]> {
    return this.datasource.listPendingForUser(userId);
  }
}
