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

/** radiusKm is clamped to 0.5..50 and limit to at most 50 by the datasource. */
export const nearbyPlacesQuerySchema = z.object({
  lat: z.coerce.number().min(-90).max(90),
  lng: z.coerce.number().min(-180).max(180),
  radiusKm: z.coerce.number().positive().optional(),
  vibe: vibeSchema.optional(),
  limit: z.coerce.number().int().positive().optional(),
  offset: z.coerce.number().int().nonnegative().optional(),
});

/**
 * place_hours.opens_at / closes_at are Postgres TIME columns.
 * Accept "HH:mm", "HH:mm:ss", or a full ISO datetime (time portion used).
 */
const timeOfDaySchema = z
  .union([z.string(), z.date()])
  .nullable()
  .optional()
  .transform((value, ctx) => {
    if (value == null || value === "") return null;
    if (value instanceof Date) {
      if (Number.isNaN(value.getTime())) {
        ctx.addIssue({ code: "custom", message: "Invalid time" });
        return z.NEVER;
      }
      return value;
    }

    const trimmed = value.trim();
    const hm = /^([01]?\d|2[0-3]):([0-5]\d)(?::([0-5]\d))?$/.exec(trimmed);
    if (hm) {
      const hours = Number(hm[1]);
      const minutes = Number(hm[2]);
      const seconds = Number(hm[3] ?? "0");
      return new Date(Date.UTC(1970, 0, 1, hours, minutes, seconds));
    }

    const parsed = new Date(trimmed);
    if (Number.isNaN(parsed.getTime())) {
      ctx.addIssue({
        code: "custom",
        message: "Expected HH:mm, HH:mm:ss, or an ISO datetime",
      });
      return z.NEVER;
    }
    return parsed;
  });

export const upsertPlaceHourBodySchema = z
  .object({
    day: weekdaySchema,
    opens_at: timeOfDaySchema,
    closes_at: timeOfDaySchema,
    is_closed: z.boolean().optional(),
  })
  .superRefine((data, ctx) => {
    const closed = data.is_closed === true;
    if (!closed && (data.opens_at == null || data.closes_at == null)) {
      ctx.addIssue({
        code: "custom",
        path: ["opens_at"],
        message:
          "opens_at and closes_at are required when is_closed is false or omitted",
      });
    }
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
