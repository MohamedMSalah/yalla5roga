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
  user: PublicUser | null;
};
