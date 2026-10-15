export type AuthUser = {
  uid: string;
  email?: string;
  name?: string;
  /** Present only when Firebase has verified a phone for this account. */
  phone?: string;
  /** `google.com`, `apple.com`, `phone`, `password`, or another Firebase provider. */
  signInProvider?: string;
};

declare global {
  namespace Express {
    interface Request {
      user?: AuthUser;
    }
  }
}

export {};
