import type { group_members, group_role, groups } from "@prisma/client";

export type Group = groups;
export type GroupMember = group_members;
export type GroupRole = group_role;

export type CreateGroupInput = {
  name: string;
  bio?: string;
  image_url: string;
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
