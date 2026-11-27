
import type { Prisma, transportation_mode, user_location_privacy } from "@prisma/client";
import { StartingLocationOverrideRepository } from "../../repositories/users/starting-location-override.repository.js";
import type { StartingLocationContext, StartingLocationOverride } from "../../types/users/starting-location-override.js";
import { EffectiveTransportationResolver } from "./effective-transportation-resolver.js";
import { LocationPrivacyPolicy } from "./location-privacy-policy.js";

type Owner = {
  userId: string;
  privacy: user_location_privacy | null;
  excluded: boolean;
  accountMode: transportation_mode | null;
};

type Personal = NonNullable<Awaited<ReturnType<StartingLocationOverrideRepository["personal"]>>>;
type Bookmark = NonNullable<Awaited<ReturnType<StartingLocationOverrideRepository["bookmark"]>>>;

export class ContextStartingLocationResolver {
  constructor(
    private readonly repository = new StartingLocationOverrideRepository(),
    private readonly privacy = new LocationPrivacyPolicy(),
    private readonly transportation = new EffectiveTransportationResolver(),
  ) {}

  private referenced(personal: Personal | null, bookmark: Bookmark | null) {
    const catalog = bookmark?.places;
    if (catalog && (!catalog.is_active || catalog.status !== "active")) return null;
    const point = this.privacy.startingPoint({ saved_location: personal, saved_place: bookmark });
    const reference = personal ?? catalog;
    if (!point || !reference) return null;
    const place = personal?.place ?? catalog;
    const district = place?.is_active && place.status === "active" &&
      point.latitude === place.latitude && point.longitude === place.longitude ? place.district : null;
    return {
      point, district, name: reference.name, name_ar: catalog?.name_ar ?? null,
      mode: personal?.preferred_transportation_mode ?? bookmark?.preferred_transportation_mode ?? null,
    };
  }

  private temporary(override: StartingLocationOverride & { personal_location: Personal | null; saved_place: Bookmark | null }) {
    if (override.location_source === "MANUAL_POINT") {
      const point = this.privacy.startingPoint({ saved_location: override, saved_place: null });
      return point && { point, name: null, name_ar: null, district: null, mode: null };
    }
    return this.referenced(override.personal_location, override.saved_place);
  }

  async resolveMany(tx: Prisma.TransactionClient, context: StartingLocationContext, owners: Owner[],
    now: Date) {
    const eligible = owners.filter(owner => !owner.excluded);
    const overrides = await this.repository.list(tx, context, eligible.map(owner => owner.userId), now);
    const byOverrideOwner = new Map(overrides.map(row => [row.user_id, row]));
    const defaultAuthorized = new Set(eligible.filter(owner => {
      const override = byOverrideOwner.get(owner.userId);
      return (context.kind === "meetup" && this.privacy.hasValidConsent(owner.privacy)) ||
        (override?.location_source === "DEFAULT" && override.consent_policy_version !== null);
    }).map(owner => owner.userId));
    const defaults = await this.repository.defaults(tx, [...defaultAuthorized]);
    const byDefaultOwner = new Map(defaults.map(row => [row.user_id, row]));
    return new Map(owners.map(owner => {
      const override = byOverrideOwner.get(owner.userId);
      const selection = byDefaultOwner.get(owner.userId);
      const temporary = override && this.temporary(override);
      const location = temporary || (selection && this.referenced(selection.saved_location, selection.saved_place)) || null;
      const transportation = this.transportation.resolvePreferences(
        override?.transportation_mode, location?.mode, owner.accountMode,
      );
      const status = location ? "READY" : owner.excluded ? "GROUP_EXCLUDED" :
        defaultAuthorized.has(owner.userId) ? "STARTING_LOCATION_REQUIRED" : "CONSENT_REQUIRED";
      const district = temporary ? null : this.privacy.sharedArea(owner.privacy, location?.district ?? null).district;
      return [owner.userId, {
        status, location, transportation, override: override ?? null, temporary: Boolean(temporary),
        // Groups retain their existing district visibility rules for permanent locations.
        district,
        dependency: [!temporary && this.privacy.hasValidConsent(owner.privacy) ? owner.privacy.location_usage_consent_at : null, owner.excluded,
          override?.id, override?.updated_at, override?.expires_at,
          temporary ? null : selection?.saved_location_id, temporary ? null : selection?.saved_place_id,
          location?.point, district, location ? transportation : null],
      }] as const;
    }));
  }
}
