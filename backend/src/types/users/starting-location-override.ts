
import type { starting_location_overrides, transportation_mode } from "@prisma/client";

export type StartingLocationOverride = starting_location_overrides;

// Context-only use does not extend the account's automatic Smart Meetup policy.
export const startingLocationContextConsentVersion = "starting-location-context-v1";

export type StartingLocationContext =
  | { kind: "meetup"; id: string }
  | { kind: "outing"; id: string };

export type StartingLocationOverrideInput = {
  transportation_mode?: transportation_mode | null;
} & (
  | { location_source: "DEFAULT"; consent_policy_version?: string }
  | { location_source: "PERSONAL_LOCATION"; personal_location_id: string; consent_policy_version: string }
  | { location_source: "SAVED_PLACE"; saved_place_id: string; consent_policy_version: string }
  | { location_source: "MANUAL_POINT"; latitude: number; longitude: number; consent_policy_version: string }
);
