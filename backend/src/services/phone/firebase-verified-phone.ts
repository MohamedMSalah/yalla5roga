import { getFirebaseAuth } from "../../config/firebase.js";

/**
 * Firebase includes phone_number on an ID token only after the number is verified.
 * A profile phone saved during email sign-up is not treated as verified.
 */
export interface VerifiedPhoneLookup {
  findUserIdByVerifiedPhone(e164: string): Promise<string | null>;
}

export class FirebaseVerifiedPhoneLookup implements VerifiedPhoneLookup {
  async findUserIdByVerifiedPhone(e164: string): Promise<string | null> {
    try {
      const record = await getFirebaseAuth().getUserByPhoneNumber(e164);
      return record.uid;
    } catch (error) {
      if (isFirebaseUserNotFound(error)) return null;
      throw error;
    }
  }
}

function isFirebaseUserNotFound(error: unknown): boolean {
  return (
    typeof error === "object" &&
    error !== null &&
    "code" in error &&
    (error as { code?: unknown }).code === "auth/user-not-found"
  );
}
