import { z } from "zod";

const placeId = z.uuid();
const reviewId = z.uuid();
export const reviewPlaceParams = z.object({ placeId });
export const reviewTargetParams = z.object({ placeId, reviewId });
export const reviewEntityParams = z.object({ id: z.uuid() });

export const placeRatingBody = z.strictObject({
  rating: z.number().int().min(1).max(5),
  reviewText: z.string().trim().max(1000).nullable().optional().transform((text) => text || null)
    .refine((text) => text === null || !/[\p{Cc}]/u.test(text.replace(/[\r\n\t]/g, ""))
      && (text.match(/(?:https?:\/\/|www\.)/gi)?.length ?? 0) <= 1,
      "Review text contains unsupported characters or too many links"),
});
export const reviewReportBody = z.strictObject({
  reason: z.enum(["spam", "harassment", "inappropriate", "off_topic", "other"]),
});
export const reviewModerationBody = z.strictObject({
  moderationStatus: z.enum(["visible", "hidden"]),
});
export const reviewPageQuery = z.object({
  limit: z.coerce.number().int().min(1).max(50).default(15),
  cursor: z.string().max(160).regex(/^[A-Za-z0-9_-]+$/).optional(),
});
