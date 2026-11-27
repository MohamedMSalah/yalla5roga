import { z } from "zod";
import { transportationModes } from "../../types/users/transportation.types.js";

export const nullableTransportationMode = z.enum(transportationModes).nullable();
export const updateTransportationPreferencesSchema = z.strictObject({
  default_transportation_mode: nullableTransportationMode,
});
export const updateBookmarkTransportationSchema = z.strictObject({
  preferred_transportation_mode: nullableTransportationMode,
});
