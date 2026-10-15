import { z } from "zod";

const vibeSchema = z.enum(["food", "activity", "outdoor", "movie"]);
const priceLevelSchema = z.enum([
  "free",
  "budget",
  "moderate",
  "expensive",
  "luxury",
]);
const weekdaySchema = z.enum([
  "monday",
  "tuesday",
  "wednesday",
  "thursday",
  "friday",
  "saturday",
  "sunday",
]);

export const createPlaceBodySchema = z.object({
  name: z.string().trim().min(1).max(100),
  area: z.string().trim().max(100).optional(),
  vibe: vibeSchema.optional(),
  description: z.string().trim().max(1000).optional(),
  cover_image_url: z.url().max(2048).optional(),
  price_level: priceLevelSchema.optional(),
  price_min: z.number().nonnegative().optional().nullable(),
  price_max: z.number().nonnegative().optional().nullable(),
  currency: z.string().length(3).optional(),
  latitude: z.number().optional().nullable(),
  longitude: z.number().optional().nullable(),
  featured: z.boolean().optional(),
});

export const updatePlaceBodySchema = createPlaceBodySchema.partial();

export const placeIdParamsSchema = z.object({
  id: z.uuid(),
});

export const listPlacesQuerySchema = z.object({
  featured: z
    .enum(["true", "false"])
    .optional()
    .transform((value) => value === "true"),
});

export const upsertPlaceHourBodySchema = z.object({
  day: weekdaySchema,
  opens_at: z.coerce.date().optional().nullable(),
  closes_at: z.coerce.date().optional().nullable(),
  is_closed: z.boolean().optional(),
});

export const placeHourIdParamsSchema = z.object({
  id: z.uuid(),
  hourId: z.uuid(),
});

export const createPlaceImageBodySchema = z.object({
  image_url: z.url().max(2048),
  caption: z.string().trim().max(200).optional().nullable(),
  sort_order: z.number().int().optional(),
});

export const placeImageIdParamsSchema = z.object({
  id: z.uuid(),
  imageId: z.uuid(),
});

export const createPlacePriceBodySchema = z.object({
  label: z.string().trim().min(1).max(80),
  amount: z.number().nonnegative(),
  currency: z.string().length(3).optional(),
});

export const placePriceIdParamsSchema = z.object({
  id: z.uuid(),
  priceId: z.uuid(),
});
