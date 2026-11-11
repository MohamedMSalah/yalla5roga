import { getFirebaseAuth } from "../../config/firebase.js";
import { tryNormalizePhoneNumber } from "./normalize-phone.js";
import { UnauthorizedError } from "../../utils/errors.js";
import type { Auth } from "firebase-admin/auth";

export type PhoneProof = { uid: string; phone: string };

export class FirebasePhoneIdentity {
  constructor(
    private readonly auth: () => Pick<Auth, "verifyIdToken" | "getUser" | "updateUser"> = getFirebaseAuth,
    private readonly now = Date.now,
  ) {}

  async verifyProof(token: string): Promise<PhoneProof> {
    const { uid, phone } = await this.verifyRecoveryProof(token);
    return { uid, phone };
  }

  async verifyRecoveryProof(token: string): Promise<PhoneProof & { authTime: number }> {
    try {
      const decoded = await this.auth().verifyIdToken(token, true);
      const phone = tryNormalizePhoneNumber(decoded.phone_number ?? "");
      const age = this.now() / 1000 - decoded.auth_time;
      if (!phone || decoded.firebase.sign_in_provider !== "phone" || !Number.isFinite(age) || age < -60 || age > 600) {
        throw new Error("A recent phone sign-in is required");
      }
      // A token for a phone removed from an identity is no longer proof.
      if ((await this.verifiedPhone(decoded.uid)) !== phone) {
        throw new Error("Phone identity changed");
      }
      return { uid: decoded.uid, phone, authTime: decoded.auth_time };
    } catch {
      throw new UnauthorizedError("Verify your phone number again");
    }
  }

  async verifiedPhone(uid: string): Promise<string | null> {
    const user = await this.auth().getUser(uid);
    return user.disabled ? null : tryNormalizePhoneNumber(user.phoneNumber ?? "");
  }

  /** Caller must establish that the proof UID has no other Neon account. */
  async bindPhone(userId: string, proof: PhoneProof): Promise<void> {
    if (userId === proof.uid) return;
    const auth = this.auth();
    // Preserve the canonical UID and all its PostgreSQL relationships. Only
    // move the phone credential from the unused signup-OTP identity.
    await auth.updateUser(proof.uid, { phoneNumber: null });
    try {
      await auth.updateUser(userId, { phoneNumber: proof.phone });
    } catch (error) {
      await auth.updateUser(proof.uid, { phoneNumber: proof.phone });
      throw error;
    }
  }
}
