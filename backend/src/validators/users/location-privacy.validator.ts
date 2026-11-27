import { z } from "zod";
import { locationVisibilityValues } from "../../types/users/location-privacy.types.js";

export const updateLocationVisibilitySchema = z.strictObject({
  location_visibility: z.enum(locationVisibilityValues),
});

export const grantLocationConsentSchema = z.strictObject({
  consent_policy_version: z.string().trim().min(1).max(64),
});

export const locationExclusionParamsSchema = z.object({ groupId: z.uuid() });

export const sharedStartingAreaParamsSchema = locationExclusionParamsSchema.extend({
  userId: z.string().min(1).max(128),
});
