import { z } from "zod";
import { nullableTransportationMode } from "./transportation.validator.js";
import {
  savedLocationTypes,
  startingLocationSources,
} from "../../types/users/saved-location.types.js";

export const savedLocationIdParamsSchema = z.object({ id: z.uuid() });
export const savedLocationBodySchema = z.strictObject({
  name: z.string().trim().min(1).max(100),
  location_type: z.enum(savedLocationTypes),
  latitude: z.number().min(-90).max(90),
  longitude: z.number().min(-180).max(180),
  approximate_area: z.string().trim().min(1).max(100).nullable().optional(),
  address: z.string().trim().min(1).max(1000).nullable().optional(),
  place_id: z.uuid().nullable().optional(),
  preferred_transportation_mode: nullableTransportationMode.optional(),
});
export const updateSavedLocationBodySchema = savedLocationBodySchema.partial()
  .refine((value) => Object.keys(value).length > 0, "Provide at least one field")
  .refine(
    ({ latitude, longitude }) => (latitude === undefined) === (longitude === undefined),
    "Provide latitude and longitude together",
  );
export const startingLocationSelectionSchema = z.strictObject({
  source: z.enum(startingLocationSources),
  referenceId: z.uuid(),
});
