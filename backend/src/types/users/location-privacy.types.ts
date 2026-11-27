export const locationVisibilityValues = ["APPROXIMATE", "HIDDEN"] as const;
export type LocationVisibility = typeof locationVisibilityValues[number];

// A version applies only to internal Smart Meetup calculations with saved points.
export const locationUsagePolicyVersion = "smart-meetup-location-v1";
export const locationSetupStatuses = [
  "READY",
  "CONSENT_REQUIRED",
  "STARTING_LOCATION_REQUIRED",
] as const;

export type SharedStartingArea =
  | { status: "APPROXIMATE"; district: string }
  | { status: "HIDDEN" | "UNAVAILABLE"; district: null };

export type StartingPoint = Readonly<{ latitude: number; longitude: number }>;
