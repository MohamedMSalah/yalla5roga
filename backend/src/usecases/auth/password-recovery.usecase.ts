import { createHash, randomBytes } from "node:crypto";
import { UserRepository } from "../../repositories/users/user.repository.js";
import { PasswordRecoveryRepository, type Recovery } from "../../repositories/auth/password-recovery.repository.js";
import { FirebasePhoneIdentity } from "../../services/phone/phone-identity.js";
import { hashPassword } from "../../services/auth/password.js";
import { normalizePhoneNumber } from "../../services/phone/normalize-phone.js";
import { UnauthorizedError, ValidationError } from "../../utils/errors.js";
import { resetPasswordBodySchema } from "../../validators/auth/auth.validator.js";

export const recoveryDigest = (value: string) => createHash("sha256").update(value).digest("hex");
const secret = () => randomBytes(32).toString("base64url");
const unavailable = () => new ValidationError("Recovery is unavailable for this number. Check the number or contact support");

export class PasswordRecoveryUseCase {
  constructor(
    private readonly store = new PasswordRecoveryRepository(),
    private readonly users: Pick<UserRepository, "findByPhone" | "findById"> = new UserRepository(),
    private readonly phones: Pick<FirebasePhoneIdentity, "verifyRecoveryProof" | "verifiedPhone"> = new FirebasePhoneIdentity(),
    private readonly clock = Date.now,
  ) {}

  async limit(ip: string): Promise<void> {
    await this.store.limit(recoveryDigest(`ip:${ip}`), 30, 60, new Date(this.clock()));
  }

  async start(phoneInput: string) {
    const now = new Date(this.clock());
    const phone = normalizePhoneNumber(phoneInput);
    await this.store.cleanup(now);
    await this.store.limit(recoveryDigest(`phone-hour:${phone}`), 5, 3600, now);
    await this.store.limit(recoveryDigest(`phone-cooldown:${phone}`), 1, 60, now);
    const user = await this.users.findByPhone(phone);
    if (!user?.password_hash) throw unavailable();
    // Do not bootstrap Firebase identities or trust an unverified profile phone.
    if (await this.phones.verifiedPhone(user.id) !== phone) throw unavailable();
    const requestToken = secret();
    await this.store.create({ request_hash: recoveryDigest(requestToken), user_id: user.id,
      phone, password_version: recoveryDigest(user.password_hash), created_at: now,
      expires_at: new Date(now.getTime() + 600_000), proof_hash: null, reset_hash: null, consumed_at: null });
    return { requestToken, expiresIn: 600, resendAfter: 60 };
  }

  async verify(requestToken: string, phoneVerificationToken: string) {
    const now = new Date(this.clock());
    const requestHash = recoveryDigest(requestToken);
    await this.store.limit(recoveryDigest(`verify:${requestHash}`), 5, 600, now);
    const row = await this.store.find(requestHash);
    this.assertActive(row, now);
    if (row.proof_hash) throw new UnauthorizedError("Phone proof already used. Request a new code");
    // Firebase validates signature, audience, expiration, revocation and phone provider.
    const proof = await this.phones.verifyRecoveryProof(phoneVerificationToken);
    if (proof.uid !== row.user_id || proof.phone !== row.phone ||
        proof.authTime < Math.floor(row.created_at.getTime() / 1000) ||
        proof.authTime > Math.floor(now.getTime() / 1000) ||
        now.getTime() / 1000 - proof.authTime > 300) {
      throw new UnauthorizedError("Verify this recovery phone with a new code");
    }
    await this.assertAccount(row);
    const resetToken = secret();
    // Bind replay protection to the phone sign-in, not to a refreshable ID token.
    const proofHash = recoveryDigest(`${proof.uid}:${proof.authTime}`);
    await this.store.authorize(requestHash, proofHash, recoveryDigest(resetToken), now);
    return { resetToken, expiresIn: 300 };
  }

  async reset(input: { resetToken: string; newPassword: string; confirmPassword: string }) {
    const parsed = resetPasswordBodySchema.safeParse(input);
    if (!parsed.success) throw new ValidationError("Check password length and confirmation");
    const now = new Date(this.clock());
    const resetHash = recoveryDigest(input.resetToken);
    await this.store.limit(recoveryDigest(`reset:${resetHash}`), 5, 600, now);
    const row = await this.store.findReset(resetHash);
    this.assertActive(row, now);
    if (!row.proof_hash) throw new UnauthorizedError("Phone verification required");
    const user = await this.assertAccount(row);
    const passwordHash = await hashPassword(input.newPassword);
    // Recheck expiration after slow password hashing and external identity lookup.
    await this.store.consume(row, passwordHash, user.password_hash!, new Date(this.clock()));
    // Existing app sessions intentionally keep their established behavior.
    return { updated: true };
  }

  private assertActive(row: Recovery | null, now: Date): asserts row is Recovery {
    if (!row || row.consumed_at || row.expires_at <= now) {
      throw new UnauthorizedError("Recovery expired. Start again");
    }
  }
  private async assertAccount(row: Recovery) {
    const user = await this.users.findById(row.user_id);
    if (!user?.password_hash || user.phone !== row.phone ||
        recoveryDigest(user.password_hash) !== row.password_version ||
        await this.phones.verifiedPhone(row.user_id) !== row.phone) throw unavailable();
    return user;
  }
}
