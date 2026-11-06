import type { IUserRepository } from "../../repositories/users/i-user.repository.js";
import { UserRepository } from "../../repositories/users/user.repository.js";
import {
  createFirebaseIdentityUser,
  deleteFirebaseIdentityUser,
  issueFirebaseSession,
} from "../../services/auth/firebase-identity.js";
import { hashPassword } from "../../services/auth/password.js";
import { toPublicUser } from "../../services/auth/to-public-user.js";
import { normalizePhoneNumber } from "../../services/phone/normalize-phone.js";
import type {
  AuthSessionResult,
  SignupInput,
} from "../../types/auth/auth.types.js";
import { ConflictError, ValidationError } from "../../utils/errors.js";
import { truncateDisplayName } from "../users/sync-user.usecase.js";

const PHONE_ALREADY_LINKED =
  "This phone number is already associated with another account";
const EMAIL_ALREADY_LINKED = "An account with this email already exists";

export class SignupUseCase {
  constructor(private readonly users: IUserRepository = new UserRepository()) {}

  async execute(input: SignupInput): Promise<AuthSessionResult> {
    if (!input.name || !input.email || !input.password || !input.phone) {
      throw new ValidationError("name, email, password, and phone are required");
    }

    const email = input.email.trim().toLowerCase();
    const phone = normalizePhoneNumber(input.phone);
    const displayName = truncateDisplayName(input.name);
    if (!displayName) {
      throw new ValidationError("name is required");
    }

    const [existingEmail, existingPhone] = await Promise.all([
      this.users.findByEmail(email),
      this.users.findByPhone(phone),
    ]);
    if (existingEmail) {
      throw new ConflictError(EMAIL_ALREADY_LINKED);
    }
    if (existingPhone) {
      throw new ConflictError(PHONE_ALREADY_LINKED);
    }

    const passwordHash = await hashPassword(input.password);
    const identity = await createFirebaseIdentityUser({
      email,
      displayName,
    });

    try {
      const now = new Date();
      const user = await this.users.create({
        id: identity.uid,
        name: displayName,
        email,
        phone,
        password_hash: passwordHash,
        password_updated_at: now,
      });

      const session = await issueFirebaseSession(identity.uid);

      return {
        idToken: session.idToken,
        refreshToken: session.refreshToken,
        expiresIn: session.expiresIn,
        uid: session.uid,
        customToken: session.customToken,
        user: toPublicUser(user),
      };
    } catch (error) {
      await this.rollbackFirebaseUser(identity.uid);
      throw error;
    }
  }

  private async rollbackFirebaseUser(uid: string) {
    try {
      await deleteFirebaseIdentityUser(uid);
    } catch (cleanupError) {
      console.error("[Auth Signup] Failed to roll back Firebase user", {
        uid,
        error:
          cleanupError instanceof Error
            ? cleanupError.message
            : String(cleanupError),
      });
    }
  }
}
