import type { users } from "@prisma/client";

export type User = users;

export type CreateUserInput = {
  id: string;
  name: string;
  phone: string | null;
  email: string;
  image_url?: string | null;
};

export type UpdateUserInput = {
  name?: string;
  phone?: string | null;
  email?: string | null;
  image_url?: string | null;
};

/**
 * Profile payload after Firebase sign-up or sign-in. Password never reaches the API.
 * `verifiedPhone` is copied from the ID token. Google and Apple sign-in do not
 * verify a phone, so it stays empty until Firebase phone linking succeeds.
 */
export type SyncUserInput = {
  id: string;
  name: string;
  email: string;
  phone?: string | null;
  image_url?: string | null;
  verifiedPhone?: string | null;
  /** Firebase `sign_in_provider`, such as `google.com`, `apple.com`, or `phone`. */
  signInProvider?: string | null;
};

export type InvitationSyncStatus =
  | "claimed"
  | "none"
  | "phone_verification_required";

export type InvitationSyncState = {
  phoneVerified: boolean;
  status: InvitationSyncStatus;
  claimedGroupIds: string[];
};

export type SyncUserResult = {
  user: User;
  invitations: InvitationSyncState;
};
