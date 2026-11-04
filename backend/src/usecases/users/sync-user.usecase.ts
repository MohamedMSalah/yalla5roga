import type { IUserRepository } from "../../repositories/users/i-user.repository.js";
import { UserRepository } from "../../repositories/users/user.repository.js";
import { ClaimGroupInvitationsUseCase } from "../groups/claim-group-invitations.usecase.js";
import { tryNormalizePhoneNumber } from "../../services/phone/normalize-phone.js";
import type {
  SyncUserInput,
  SyncUserResult,
  UpdateUserInput,
  User,
} from "../../types/users/user.types.js";
import { ConflictError, ValidationError } from "../../utils/errors.js";

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
 * applies trusted token claims (verified phone, fill-missing email) and never
 * overwrites user-managed profile fields from the request body.
 */
export class SyncUserUseCase {
  constructor(
    private readonly users: IUserRepository = new UserRepository(),
    private readonly claimInvitations: Pick<
      ClaimGroupInvitationsUseCase,
      "execute"
    > = new ClaimGroupInvitationsUseCase(),
  ) {}

  async execute(input: SyncUserInput): Promise<SyncUserResult> {
    if (!input.id) {
      throw new ValidationError("id is required");
    }

    const verifiedPhone = input.verifiedPhone
      ? tryNormalizePhoneNumber(input.verifiedPhone)
      : null;
    const existing = await this.users.findById(input.id);

    if (verifiedPhone) {
      await this.assertPhoneAvailable(verifiedPhone, input.id);
    }

    const user = existing
      ? await this.syncExisting(existing, {
          verifiedPhone,
          tokenEmail: input.tokenEmail,
        })
      : await this.createMinimalProfile(input, verifiedPhone);

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
   * Existing profiles are identity-only: verified phone may be applied, and a
   * missing email may be filled from the token. Body name / email / phone /
   * image_url never overwrite stored profile values.
   */
  private async syncExisting(
    existing: User,
    options: {
      verifiedPhone: string | null;
      tokenEmail?: string | null;
    },
  ): Promise<User> {
    const patch: UpdateUserInput = {};

    if (options.verifiedPhone && options.verifiedPhone !== existing.phone) {
      patch.phone = options.verifiedPhone;
    }

    const tokenEmail = normalizeOptionalEmail(options.tokenEmail);
    if (!existing.email && tokenEmail) {
      patch.email = tokenEmail;
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
    verifiedPhone: string | null,
  ): Promise<User> {
    const phone =
      verifiedPhone ??
      (await this.bootstrapUnverifiedPhone(input.phone, input.id));

    return this.users.create({
      id: input.id,
      name: resolveCreateName(input),
      email: resolveCreateEmail(input),
      phone,
      image_url: normalizeOptionalImageUrl(input.image_url),
    });
  }

  private async assertPhoneAvailable(phone: string, userId: string) {
    const owner = await this.users.findByPhone(phone);
    if (owner && owner.id !== userId) {
      throw new ConflictError(PHONE_ALREADY_LINKED);
    }
  }

  /**
   * Stores an unverified profile phone only when creating a row that has none.
   * Never treated as verified and never used to claim invitations.
   */
  private async bootstrapUnverifiedPhone(
    submitted: string | null | undefined,
    userId: string,
  ): Promise<string | null> {
    if (!submitted) return null;

    const normalized = tryNormalizePhoneNumber(submitted);
    if (!normalized) {
      throw new ValidationError("Invalid phone number");
    }

    await this.assertPhoneAvailable(normalized, userId);
    return normalized;
  }
}

function normalizeOptionalEmail(
  value: string | null | undefined,
): string | null {
  if (typeof value !== "string") return null;
  const trimmed = value.trim();
  return trimmed.length > 0 ? trimmed : null;
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

  const email = resolveCreateEmail(input);
  if (email) {
    const local = truncateDisplayName(email.split("@")[0] ?? "");
    if (local) return local;
  }

  return DEFAULT_DISPLAY_NAME;
}

/**
 * Prefer the verified token email. Body email is a create-time fallback only
 * (for example email/password signup before claims are copied onto the input).
 */
function resolveCreateEmail(input: SyncUserInput): string | null {
  return (
    normalizeOptionalEmail(input.tokenEmail) ??
    normalizeOptionalEmail(input.email)
  );
}
