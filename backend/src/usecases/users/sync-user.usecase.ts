import type { IUserRepository } from "../../repositories/users/i-user.repository.js";
import { UserRepository } from "../../repositories/users/user.repository.js";
import { ClaimGroupInvitationsUseCase } from "../groups/claim-group-invitations.usecase.js";
import { tryNormalizePhoneNumber } from "../../services/phone/normalize-phone.js";
import { FirebasePhoneIdentity } from "../../services/phone/phone-identity.js";
import type {
  SyncUserInput,
  SyncUserResult,
  UpdateUserInput,
  User,
} from "../../types/users/user.types.js";
import { ConflictError, UnauthorizedError, ValidationError } from "../../utils/errors.js";

const PHONE_ALREADY_LINKED =
  "This phone number is already associated with another account";

/** users.name is VarChar(30); Google and Apple display names can be longer. */
const MAX_NAME_LENGTH = 30;

const DEFAULT_DISPLAY_NAME = "User";

export function truncateDisplayName(name: string): string {
  return name.trim().slice(0, MAX_NAME_LENGTH).trimEnd();
}

/**
 * Identity sync for a verified Firebase UID.
 *
 * Creates a minimal PostgreSQL profile on first call. On later calls it only
 * applies the verified phone claim and never
 * overwrites user-managed profile fields from the request body.
 */
export class SyncUserUseCase {
  constructor(
    private readonly users: IUserRepository = new UserRepository(),
    private readonly claimInvitations: Pick<
      ClaimGroupInvitationsUseCase,
      "execute"
    > = new ClaimGroupInvitationsUseCase(),
    private readonly phones: Pick<FirebasePhoneIdentity, "verifyProof" | "bindPhone"> = new FirebasePhoneIdentity(),
  ) {}

  async execute(input: SyncUserInput): Promise<SyncUserResult> {
    if (!input.id) {
      throw new ValidationError("id is required");
    }

    let verifiedPhone = input.verifiedPhone
      ? tryNormalizePhoneNumber(input.verifiedPhone)
      : null;
    const existing = await this.users.findById(input.id);

    if (input.phoneVerificationToken) {
      const proof = await this.phones.verifyProof(input.phoneVerificationToken);
      // Never merge registered identities or transfer their phone credentials.
      if (proof.uid !== input.id && await this.users.findById(proof.uid)) {
        throw new ConflictError(PHONE_ALREADY_LINKED);
      }
      await this.assertPhoneAvailable(proof.phone, input.id);
      await this.phones.bindPhone(input.id, proof);
      verifiedPhone = proof.phone;
    } else if (verifiedPhone) {
      await this.assertPhoneAvailable(verifiedPhone, input.id);
    }

    if (!existing && !verifiedPhone) {
      throw new UnauthorizedError("Firebase phone verification is required");
    }

    const user = existing
      ? await this.syncExisting(existing, {
          verifiedPhone,
        })
      : await this.createMinimalProfile(input, verifiedPhone!);

    if (!verifiedPhone) {
      return {
        user,
        invitations: {
          phoneVerified: false,
          status: "phone_verification_required",
          claimedGroupIds: [],
        },
      };
    }

    const claimed = await this.claimInvitations.execute({
      userId: user.id,
      verifiedPhone,
    });

    return {
      user,
      invitations: {
        phoneVerified: true,
        status: claimed.length > 0 ? "claimed" : "none",
        claimedGroupIds: claimed.map((invitation) => invitation.group_id),
      },
    };
  }

  /**
   * Existing profiles are identity-only: verified phone may be applied. Body name / phone /
   * image_url never overwrite stored profile values.
   */
  private async syncExisting(
    existing: User,
    options: { verifiedPhone: string | null },
  ): Promise<User> {
    const patch: UpdateUserInput = {};

    if (options.verifiedPhone && options.verifiedPhone !== existing.phone) {
      patch.phone = options.verifiedPhone;
    }

    if (Object.keys(patch).length === 0) {
      return existing;
    }

    return this.users.update(existing.id, patch);
  }

  /**
   * First sync creates a minimal row. Body fields are bootstrap hints only when
   * the verified token does not already carry the claim.
   */
  private async createMinimalProfile(
    input: SyncUserInput,
    verifiedPhone: string,
  ): Promise<User> {
    try {
      return await this.users.create({ id: input.id, name: resolveCreateName(input),
        phone: verifiedPhone, image_url: normalizeOptionalImageUrl(input.image_url) });
    } catch (error) {
      if ((error as { code?: string }).code !== "P2002") throw error;
      const existing = await this.users.findById(input.id);
      if (existing?.phone === verifiedPhone) return existing;
      throw new ConflictError(PHONE_ALREADY_LINKED);
    }
  }

  private async assertPhoneAvailable(phone: string, userId: string) {
    const owner = await this.users.findByPhone(phone);
    if (owner && owner.id !== userId) {
      throw new ConflictError(PHONE_ALREADY_LINKED);
    }
  }

}

function normalizeOptionalImageUrl(
  value: string | null | undefined,
): string | null {
  if (typeof value !== "string") return null;
  const trimmed = value.trim();
  return trimmed.length > 0 ? trimmed : null;
}

function resolveCreateName(input: SyncUserInput): string {
  const fromBody = input.name ? truncateDisplayName(input.name) : "";
  if (fromBody) return fromBody;

  const fromToken = input.tokenName
    ? truncateDisplayName(input.tokenName)
    : "";
  if (fromToken) return fromToken;

  return DEFAULT_DISPLAY_NAME;
}
