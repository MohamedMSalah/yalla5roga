import type { users } from "@prisma/client";

export type User = users;
type UserCredentials = Pick<User, "password_hash">;
export type PublicUser = Omit<User, keyof UserCredentials> & { has_password: boolean };
export type PublicUserSummary = Pick<
  User,
  "id" | "name" | "image_url" | "created_at" | "updated_at"
>;
export type CreateUserInput = { id: string; name: string; phone: string; image_url?: string | null } & Partial<UserCredentials>;
export type UpdateUserInput = { name?: string; phone?: string; image_url?: string | null } & Partial<UserCredentials>;
export type SyncUserInput = {
  /** Identity fields are supplied from verified Firebase tokens, never body.uid. */
  id: string;
  phoneVerificationToken?: string;
  verifiedPhone?: string | null;
  tokenName?: string | null;
  signInProvider?: string | null;
  /** First-profile hints only; body phone is never proof. */
  name?: string | null;
  phone?: string | null;
  image_url?: string | null;
};
export type InvitationSyncStatus = "claimed" | "none" | "phone_verification_required";
export type InvitationSyncState = { phoneVerified: boolean; status: InvitationSyncStatus; claimedGroupIds: string[] };
export type SyncUserResult = {
  user: User;
  invitations: InvitationSyncState;
};
