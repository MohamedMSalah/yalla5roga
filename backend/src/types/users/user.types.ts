import type { users } from "@prisma/client";

export type User = users;

/** API-safe user profile — never includes credential columns. */
export type PublicUser = Omit<User, "password_hash" | "password_updated_at"> & {
  /** True when Neon stores a password_hash (phone/password accounts). */
  has_password: boolean;
};

export type CreateUserInput = {
  id: string;
  name: string;
  phone: string | null;
  image_url?: string | null;
  password_hash?: string | null;
  password_updated_at?: Date | null;
};

export type UpdateUserInput = {
  name?: string;
  phone?: string | null;
  image_url?: string | null;
  password_hash?: string | null;
  password_updated_at?: Date | null;
};

/**
 * Identity sync after Firebase sign-up or sign-in.
 * Email/password credentials are handled only by `/api/auth` (Neon password_hash).
 *
 * `id`, `verifiedPhone`, `tokenName`, and `signInProvider` must
 * come from the verified Firebase ID token — never from the client body.
 * Body `name` / `phone` / `image_url` are create-time bootstrap hints
 * only and must not overwrite an existing profile.
 */
export type SyncUserInput = {
  id: string;
  name?: string | null;
  phone?: string | null;
  image_url?: string | null;
  /** Verified Firebase `phone_number` claim. */
  verifiedPhone?: string | null;
  /** Verified Firebase `name` claim. */
  tokenName?: string | null;
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
