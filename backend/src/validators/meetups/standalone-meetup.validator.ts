import { z } from "zod";
import { transportation_mode } from "@prisma/client";

const optionalLabel = (max: number) => z.string().trim()
  .refine(value => [...value].length >= 1 && [...value].length <= max, "Invalid label length")
  .refine(value => !/[\p{Cc}\u202a-\u202e\u2066-\u2069]/u.test(value), "Invalid label characters")
  .nullable().optional();
const approximate = (max: number) => z.number().min(-max).max(max)
  .transform(value => Math.round(value * 1_000) / 1_000);

export const addManualParticipantBody = z.strictObject({
  display_name: optionalLabel(60),
  approximate_area: optionalLabel(96),
  latitude: approximate(90),
  longitude: approximate(180),
  transportation_mode: z.enum(transportation_mode).nullable().optional(),
});

export const updateManualParticipantBody = addManualParticipantBody.partial()
  .refine(value => Object.keys(value).length > 0, "Provide at least one change")
  .refine(value => (value.latitude === undefined) === (value.longitude === undefined),
    "Provide both latitude and longitude when changing the starting point");
