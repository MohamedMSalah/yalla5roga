
import { z } from "zod";
import { transportationModes } from "../../types/users/transportation.types.js";

const mode = z.enum(transportationModes);
const consent = z.string().min(1).max(64);
const temporary = {
  consent_policy_version: consent,
  transportation_mode: mode.nullish(),
};

export const startingLocationOverrideBody = z.discriminatedUnion("location_source", [
  z.strictObject({ location_source: z.literal("DEFAULT"), transportation_mode: mode.nullish(),
    consent_policy_version: consent.optional(),
  }).refine(input => input.transportation_mode != null || input.consent_policy_version !== undefined,
    "Choose transportation or authorize the default point"),
  z.strictObject({ location_source: z.literal("PERSONAL_LOCATION"), personal_location_id: z.uuid(), ...temporary }),
  z.strictObject({ location_source: z.literal("SAVED_PLACE"), saved_place_id: z.uuid(), ...temporary }),
  z.strictObject({ location_source: z.literal("MANUAL_POINT"), latitude: z.number().min(-90).max(90),
    longitude: z.number().min(-180).max(180), ...temporary }),
]);
