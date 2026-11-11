import type { IUserRepository } from "../../repositories/users/i-user.repository.js";
import { UserRepository } from "../../repositories/users/user.repository.js";
import { issueFirebaseSession } from "../../services/auth/firebase-identity.js";
import { verifyPassword } from "../../services/auth/password.js";
import { toPublicUser } from "../../services/auth/to-public-user.js";
import { normalizePhoneNumber } from "../../services/phone/normalize-phone.js";
import { FirebasePhoneIdentity } from "../../services/phone/phone-identity.js";
import { ClaimGroupInvitationsUseCase } from "../groups/claim-group-invitations.usecase.js";
import type {
  AuthSessionResult,
  LoginInput,
} from "../../types/auth/auth.types.js";
import { UnauthorizedError, ValidationError } from "../../utils/errors.js";

const INVALID_CREDENTIALS = "Invalid phone number or password";

export class LoginUseCase {
  constructor(
    private readonly users: IUserRepository = new UserRepository(),
    private readonly phones: Pick<FirebasePhoneIdentity, "verifiedPhone"> = new FirebasePhoneIdentity(),
    private readonly claims: Pick<ClaimGroupInvitationsUseCase, "execute"> = new ClaimGroupInvitationsUseCase(),
    private readonly issueSession = issueFirebaseSession,
  ) {}

  async execute(input: LoginInput): Promise<AuthSessionResult> {
    if (!input.phone || !input.password) {
      throw new ValidationError("phone and password are required");
    }

    const phone = normalizePhoneNumber(input.phone);
    const user = await this.users.findByPhone(phone);

    // Missing user, social/phone-only account, or wrong password all map to
    // the same error so callers cannot probe which phone numbers exist.
    if (!user?.password_hash) {
      throw new UnauthorizedError(INVALID_CREDENTIALS);
    }

    const matches = await verifyPassword(input.password, user.password_hash);
    if (!matches) {
      throw new UnauthorizedError(INVALID_CREDENTIALS);
    }

    const session = await this.issueSession(user.id);
    if (await this.phones.verifiedPhone(user.id) === phone) {
      await this.claims.execute({ userId: user.id, verifiedPhone: phone });
    }

    return {
      idToken: session.idToken,
      refreshToken: session.refreshToken,
      expiresIn: session.expiresIn,
      uid: session.uid,
      customToken: session.customToken,
      user: toPublicUser(user),
    };
  }
}
