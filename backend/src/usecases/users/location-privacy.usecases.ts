import { randomUUID } from "node:crypto";
import type { Prisma } from "@prisma/client";
import { LocationPrivacyRepository } from "../../repositories/users/location-privacy.repository.js";
import { LocationPrivacyPolicy } from "../../services/users/location-privacy-policy.js";
import { LocationUsageAuthorizationService } from "../../services/users/location-usage-authorization.service.js";
import {
  locationUsagePolicyVersion,
  type LocationVisibility,
} from "../../types/users/location-privacy.types.js";
import { ConflictError, ForbiddenError, NotFoundError } from "../../utils/errors.js";

class LocationPrivacyUseCase {
  constructor(
    protected readonly repository = new LocationPrivacyRepository(),
    protected readonly policy = new LocationPrivacyPolicy(),
  ) {}

  protected async owner(tx: Prisma.TransactionClient, userId: string, edit = false) {
    const [owner] = await this.repository.lockUsers(tx, [userId], edit);
    if (!owner) throw new NotFoundError("User");
    return owner;
  }

  protected async settings(tx: Prisma.TransactionClient, owner: { id: string; created_at: Date }) {
    const privacy = await this.repository.get(tx, owner.id);
    const enabled = this.policy.hasValidConsent(privacy);
    const startingPoint = enabled
      ? this.policy.startingPoint(await this.repository.getStartingPoint(tx, owner.id))
      : null;
    return {
      location_visibility: privacy?.location_visibility ?? "APPROXIMATE",
      automatic_meetup_location_usage_enabled: enabled,
      location_usage_consent_at: privacy?.location_usage_consent_at ?? null,
      consent_policy_version: privacy?.consent_policy_version ?? null,
      required_consent_policy_version: locationUsagePolicyVersion,
      updated_at: privacy?.updated_at ?? owner.created_at,
      setup_status: !enabled ? "CONSENT_REQUIRED" : startingPoint ? "READY" : "STARTING_LOCATION_REQUIRED",
    };
  }
}

export class GetLocationPrivacyUseCase extends LocationPrivacyUseCase {
  execute(userId: string) {
    return this.repository.transaction(async (tx) => this.settings(tx, await this.owner(tx, userId)));
  }
}

export class UpdateLocationVisibilityUseCase extends LocationPrivacyUseCase {
  execute(userId: string, visibility: LocationVisibility) {
    return this.repository.transaction(async (tx) => {
      const owner = await this.owner(tx, userId, true);
      const privacy = await this.repository.get(tx, userId);
      if ((privacy?.location_visibility ?? "APPROXIMATE") !== visibility) {
        await this.repository.set(tx, userId, { location_visibility: visibility });
      }
      return this.settings(tx, owner);
    });
  }
}

export class GrantLocationUsageConsentUseCase extends LocationPrivacyUseCase {
  execute(userId: string, acceptedPolicyVersion: string) {
    if (acceptedPolicyVersion !== locationUsagePolicyVersion) {
      throw new ConflictError("Read and accept the current Smart Meetup location policy");
    }
    return this.repository.transaction(async (tx) => {
      const owner = await this.owner(tx, userId, true);
      const privacy = await this.repository.get(tx, userId);
      if (!this.policy.hasValidConsent(privacy)) {
        await this.repository.set(tx, userId, {
          automatic_meetup_location_usage_enabled: true,
          location_usage_consent_at: new Date(),
          consent_policy_version: locationUsagePolicyVersion,
          authorization_revision: randomUUID(),
        });
      }
      return this.settings(tx, owner);
    });
  }
}

export class WithdrawLocationUsageConsentUseCase extends LocationPrivacyUseCase {
  execute(userId: string) {
    return this.repository.transaction(async (tx) => {
      const owner = await this.owner(tx, userId, true);
      const privacy = await this.repository.get(tx, userId);
      await tx.starting_location_overrides.deleteMany({ where: { user_id: userId } });
      if (privacy?.automatic_meetup_location_usage_enabled) {
        await this.repository.set(tx, userId, {
          automatic_meetup_location_usage_enabled: false,
          location_usage_consent_at: null,
          consent_policy_version: null,
          authorization_revision: randomUUID(),
        });
      }
      return this.settings(tx, owner);
    });
  }
}

export class ListGroupLocationExclusionsUseCase extends LocationPrivacyUseCase {
  execute(userId: string) {
    return this.repository.listExclusions(userId);
  }
}

export class SetGroupLocationExclusionUseCase extends LocationPrivacyUseCase {
  execute(userId: string, groupId: string, excluded: boolean) {
    return this.repository.transaction(async (tx) => {
      await this.owner(tx, userId, true);
      await this.repository.lockGroup(tx, groupId);
      if (!(await this.repository.lockMemberships(tx, groupId, [userId])).length) {
        throw new ForbiddenError("Current group membership required");
      }
      const existing = await this.repository.getExclusion(tx, userId, groupId);
      if (Boolean(existing) !== excluded) {
        await this.repository.changeExclusion(tx, userId, groupId, excluded);
        await this.repository.set(tx, userId, { authorization_revision: randomUUID() });
      }
      return { group_id: groupId, excluded };
    });
  }
}

export class ResolveAuthorizedStartingLocationUseCase {
  constructor(private readonly authorization = new LocationUsageAuthorizationService()) {}

  execute(groupId: string, requesterId: string, subjectId: string) {
    return this.authorization.resolveForCalculation(groupId, requesterId, [subjectId]);
  }
}
