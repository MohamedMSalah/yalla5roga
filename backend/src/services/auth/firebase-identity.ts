import { getFirebaseAuth } from "../../config/firebase.js";
import { signInWithCustomTokenSession } from "../../config/firebase-client.js";
import type { EmailPasswordSession } from "../../config/firebase-client.js";
import { mapFirebaseAuthError } from "./firebase-auth-errors.js";

export type CreateIdentityUserInput = {
  email: string;
  displayName: string;
};

export type IdentityUser = {
  uid: string;
  email: string | null;
};

/**
 * Creates a Firebase Auth identity record without a password.
 * Email/password credentials are stored only in Neon.
 */
export async function createFirebaseIdentityUser(
  input: CreateIdentityUserInput,
): Promise<IdentityUser> {
  try {
    const record = await getFirebaseAuth().createUser({
      email: input.email,
      displayName: input.displayName,
      emailVerified: false,
    });
    return { uid: record.uid, email: record.email ?? null };
  } catch (error) {
    throw mapFirebaseAuthError(error);
  }
}

export async function deleteFirebaseIdentityUser(uid: string): Promise<void> {
  await getFirebaseAuth().deleteUser(uid);
}

/**
 * Mints a Firebase custom token and exchanges it for an ID token session
 * so API clients keep using Bearer Firebase ID tokens.
 */
export async function issueFirebaseSession(
  uid: string,
): Promise<EmailPasswordSession> {
  try {
    const customToken = await getFirebaseAuth().createCustomToken(uid);
    return signInWithCustomTokenSession(customToken);
  } catch (error) {
    throw mapFirebaseAuthError(error);
  }
}
