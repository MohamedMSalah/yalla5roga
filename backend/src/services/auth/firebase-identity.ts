import { getFirebaseAuth } from "../../config/firebase.js";
import { signInWithCustomTokenSession } from "../../config/firebase-client.js";
import type { FirebaseSession } from "../../config/firebase-client.js";
import { mapFirebaseAuthError } from "./firebase-auth-errors.js";
import { isDeletedAccount } from "../users/account-deletion-access.js";
import { UnauthorizedError } from "../../utils/errors.js";

/**
 * Mints a Firebase custom token and exchanges it for an ID token session
 * so API clients keep using Bearer Firebase ID tokens.
 */
export async function issueFirebaseSession(
  uid: string,
): Promise<FirebaseSession> {
  if (isDeletedAccount(uid)) throw new UnauthorizedError("Account deleted");
  try {
    const customToken = await getFirebaseAuth().createCustomToken(uid);
    if (isDeletedAccount(uid)) throw new UnauthorizedError("Account deleted");
    const session = await signInWithCustomTokenSession(customToken);
    if (isDeletedAccount(uid)) throw new UnauthorizedError("Account deleted");
    return session;
  } catch (error) {
    throw mapFirebaseAuthError(error);
  }
}
