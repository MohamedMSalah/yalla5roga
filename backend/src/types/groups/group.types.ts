import type { group_members, group_role, groups, invitation_status } from "@prisma/client";

/** Persisted group row plus list/detail stats for API responses. */
export type Group = groups & {
  /** Accepted members in `group_members` (creator included from create). */
  member_count?: number;
  /** Caller's role when listed via `/cuser` or similar scoped queries. */
  my_role?: group_role;
};

export type GroupMember = group_members;
export type GroupRole = group_role;

/** Membership row enriched with profile fields for list/UI cards. */
export type GroupMemberView = GroupMember & {
  name: string;
  phone: string | null;
  image_url: string | null;
};

export type PendingGroupMemberView = {
  invitation_id: string;
  phone: string;
  status: "pending";
};

export type GroupRoster = {
  members: GroupMemberView[];
  pendingMembers: PendingGroupMemberView[];
  invitationHistory?: Array<{
    invitation_id: string;
    invited_phone: string;
    invitee_name: string | null;
    inviter_name: string;
    status: invitation_status;
    created_at: Date;
  }>;
};

export type CreateGroupInput = {
  name: string;
  bio?: string;
  /** Defaults to "" in the database when omitted. */
  image_url?: string;
  created_by: string;
};

export type UpdateGroupInput = {
  name?: string;
  bio?: string;
  image_url?: string;
};

export type AddGroupMemberInput = {
  group_id: string;
  user_id: string;
  role?: GroupRole;
};

export type AddGroupMemberByPhoneInput = {
  group_id: string;
  phoneNumber: string;
  role?: GroupRole;
};
