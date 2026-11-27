import type { user_location_privacy } from "@prisma/client";
import {
  locationUsagePolicyVersion,
  type SharedStartingArea,
  type StartingPoint,
} from "../../types/users/location-privacy.types.js";

type Privacy = user_location_privacy | null;
type Coordinates = { latitude: number | null; longitude: number | null };

export class LocationPrivacyPolicy {
  hasValidConsent(privacy: Privacy): privacy is user_location_privacy {
    return privacy !== null &&
      privacy.automatic_meetup_location_usage_enabled &&
      privacy.consent_policy_version === locationUsagePolicyVersion &&
      privacy.location_usage_consent_at !== null &&
      privacy.location_usage_consent_at.getTime() <= Date.now();
  }

  isHidden(privacy: Privacy) {
    return privacy?.location_visibility === "HIDDEN";
  }

  startingPoint(selection: {
    saved_location: Coordinates | null;
    saved_place: { places: Coordinates } | null;
  } | null): StartingPoint | null {
    const point = selection?.saved_location ?? selection?.saved_place?.places;
    const { latitude, longitude } = point ?? {};
    if (typeof latitude !== "number" || !Number.isFinite(latitude) || Math.abs(latitude) > 90 ||
        typeof longitude !== "number" || !Number.isFinite(longitude) || Math.abs(longitude) > 180) {
      return null;
    }
    return { latitude, longitude };
  }

  sharedArea(privacy: Privacy, catalogDistrict: string | null): SharedStartingArea {
    if (this.isHidden(privacy)) return { status: "HIDDEN", district: null };
    const district = catalogDistrict?.trim();
    // Fail closed on location-like free text, street labels, numbers or punctuation.
    if (!district || !/^[\p{L}\p{M}]+(?:[ -][\p{L}\p{M}]+)*$/u.test(district) ||
        /(?:^|[ -])(?:street|st|road|rd|avenue|ave|lane|ln|building|floor|apartment|شارع|طريق|عمارة|شقة|ميدان)(?:$|[ -])/iu.test(district)) {
      return { status: "UNAVAILABLE", district: null };
    }
    return { status: "APPROXIMATE", district };
  }
}
