import type { IUserRepository } from "../../repositories/users/i-user.repository.js";
import { UserRepository } from "../../repositories/users/user.repository.js";
import { issueFirebaseSession } from "../../services/auth/firebase-identity.js";
import { hashPassword, verifyPassword } from "../../services/auth/password.js";
import { toPublicUser } from "../../services/auth/to-public-user.js";
import { normalizePhoneNumber } from "../../services/phone/normalize-phone.js";
import type {
  AuthSessionResult,
  SignupInput,
} from "../../types/auth/auth.types.js";
import { FirebasePhoneIdentity } from "../../services/phone/phone-identity.js";
import { ConflictError, UnauthorizedError, ValidationError } from "../../utils/errors.js";
import { ClaimGroupInvitationsUseCase } from "../groups/claim-group-invitations.usecase.js";
import { truncateDisplayName } from "../users/sync-user.usecase.js";

const PHONE_ALREADY_LINKED =
  "This phone number is already associated with another account";

export class SignupUseCase {
  constructor(
    private readonly users: IUserRepository = new UserRepository(),
    private readonly phones: Pick<FirebasePhoneIdentity, "verifyProof"> = new FirebasePhoneIdentity(),
    private readonly claims: Pick<ClaimGroupInvitationsUseCase, "execute"> = new ClaimGroupInvitationsUseCase(),
    private readonly issueSession = issueFirebaseSession,
  ) {}

  async execute(input: SignupInput): Promise<AuthSessionResult> {
    if (!input.name || !input.password || !input.phone) {
      throw new ValidationError("name, phone, and password are required");
    }

    const phone = normalizePhoneNumber(input.phone);
    const displayName = truncateDisplayName(input.name);
    if (!displayName) {
      throw new ValidationError("name is required");
    }

    const proof = await this.phones.verifyProof(input.phoneVerificationToken);
    if (proof.phone !== phone) {
      throw new UnauthorizedError("Verified phone does not match the signup phone");
    }

    let user = await this.users.findById(proof.uid);
    let passwordHash: string | undefined;
    if (!user) {
      passwordHash = await hashPassword(input.password);
      try {
        user = await this.users.create({
          id: proof.uid,
          name: displayName,
          phone,
          password_hash: passwordHash,
        });
      } catch (error) {
        if ((error as { code?: string }).code !== "P2002") throw error;
        user = await this.users.findById(proof.uid);
      }
    }

    if (user?.phone === phone && !user.password_hash) {
      user = await this.users.enrollPassword(proof.uid, phone, passwordHash ?? await hashPassword(input.password));
    }

    // A retry can finish invitation claiming or session issuance without changing the account.
    if (!user?.password_hash || user.phone !== phone ||
        !(await verifyPassword(input.password, user.password_hash))) {
      throw new ConflictError(PHONE_ALREADY_LINKED);
    }

    await this.claims.execute({ userId: user.id, verifiedPhone: phone });
    const session = await this.issueSession(user.id);
    return { ...session, user: toPublicUser(user) };
  }
}
