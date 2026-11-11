import type { PublicUser } from "../users/user.types.js";

export type LoginInput = {
  phone: string;
  password: string;
};

export type SignupInput = {
  name: string;
  password: string;
  phone: string;
  phoneVerificationToken: string;
};

export type ChangePasswordInput = {
  userId: string;
  currentPassword: string;
  newPassword: string;
};

export type VerifyPasswordInput = {
  userId: string;
  password: string;
};

export type AuthSessionResult = {
  idToken: string;
  refreshToken: string;
  expiresIn: string;
  uid: string;
  /** Firebase custom token for client `signInWithCustomToken`. */
  customToken: string;
  user: PublicUser | null;
};
