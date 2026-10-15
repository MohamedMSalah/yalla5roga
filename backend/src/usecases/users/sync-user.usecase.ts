import type { IUserRepository } from "../../repositories/users/i-user.repository.js";
import { UserRepository } from "../../repositories/users/user.repository.js";
import { ClaimGroupInvitationsUseCase } from "../groups/claim-group-invitations.usecase.js";
import { tryNormalizePhoneNumber } from "../../services/phone/normalize-phone.js";
import type {
  SyncUserInput,
  SyncUserResult,
} from "../../types/users/user.types.js";
import { ConflictError, ValidationError } from "../../utils/errors.js";

const PHONE_ALREADY_LINKED =
  "This phone number is already associated with another account";

export class SyncUserUseCase {
  constructor(
    private readonly users: IUserRepository = new UserRepository(),
    private readonly claimInvitations: Pick<
      ClaimGroupInvitationsUseCase,
      "execute"
    > = new ClaimGroupInvitationsUseCase(),
  ) {}

  /**
   * Upserts the Firebase UID already on the token. Google, Apple, and phone
   * sign-in all use this path. Invitations are claimed only from a verified
   * token phone, never from the email address or a phone typed in the body.
   */
  async execute(input: SyncUserInput): Promise<SyncUserResult> {
    if (!input.id || !input.name || !input.email) {
      throw new ValidationError("id, name, and email are required");
    }

    const verifiedPhone = input.verifiedPhone
      ? tryNormalizePhoneNumber(input.verifiedPhone)
      : null;
    const existing = await this.users.findById(input.id);

    if (verifiedPhone) {
      await this.assertPhoneAvailable(verifiedPhone, input.id);
    }

    const phone = verifiedPhone
      ? verifiedPhone
      : await this.unverifiedProfilePhone(input.phone, existing?.phone ?? null, input.id);

    const user = await this.users.sync({
      id: input.id,
      name: input.name,
      phone,
      email: input.email,
      image_url: input.image_url,
    });

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

  private async assertPhoneAvailable(phone: string, userId: string) {
    const owner = await this.users.findByPhone(phone);
    if (owner && owner.id !== userId) {
      throw new ConflictError(PHONE_ALREADY_LINKED);
    }
  }

  /**
   * Keeps a profile phone collected before phone auth existed.
   * It is not treated as verified and cannot replace a phone already stored.
   */
  private async unverifiedProfilePhone(
    submitted: string | null | undefined,
    current: string | null,
    userId: string,
  ): Promise<string | null> {
    if (current) return current;
    if (!submitted) return null;

    const normalized = tryNormalizePhoneNumber(submitted);
    if (!normalized) {
      throw new ValidationError("Invalid phone number");
    }

    await this.assertPhoneAvailable(normalized, userId);
    return normalized;
  }
}
