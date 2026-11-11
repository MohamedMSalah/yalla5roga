import { getFirebaseAuth } from "../../config/firebase.js";
import { signInWithCustomTokenSession } from "../../config/firebase-client.js";
import type { FirebaseSession } from "../../config/firebase-client.js";
import { mapFirebaseAuthError } from "./firebase-auth-errors.js";

/**
 * Mints a Firebase custom token and exchanges it for an ID token session
 * so API clients keep using Bearer Firebase ID tokens.
 */
export async function issueFirebaseSession(
  uid: string,
): Promise<FirebaseSession> {
  try {
    const customToken = await getFirebaseAuth().createCustomToken(uid);
    return signInWithCustomTokenSession(customToken);
  } catch (error) {
    throw mapFirebaseAuthError(error);
  }
}
