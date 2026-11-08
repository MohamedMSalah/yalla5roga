import { getFirebaseAuth } from "../../config/firebase.js";
import { signInWithCustomTokenSession } from "../../config/firebase-client.js";
import type { EmailPasswordSession } from "../../config/firebase-client.js";
import { mapFirebaseAuthError } from "./firebase-auth-errors.js";

export type IdentityUser = {
  uid: string;
};

/**
 * Creates a bare Firebase Auth UID for ID-token sessions.
 *
 * Application profile and credentials (name, email, phone, password_hash)
 * live only in Neon. Do not write email/displayName/password into Firebase.
 */
export async function createFirebaseIdentityUser(): Promise<IdentityUser> {
  try {
    const record = await getFirebaseAuth().createUser({});
    return { uid: record.uid };
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
