import type { PublicUser } from "../users/user.types.js";

export type LoginInput = {
  email: string;
  password: string;
};

export type SignupInput = {
  name: string;
  email: string;
  password: string;
  phone: string;
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
