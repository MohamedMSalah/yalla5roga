import { z } from "zod";

const MEDIA_REFERENCE_PATTERN = /^media:\/\/[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$/;

/**
 * Entity image fields accept two forms:
 * - an absolute http(s) URL (existing behavior and existing rows), or
 * - a stable `media://<asset-id>` reference produced by the media upload flow.
 *
 * Local file paths are never valid here — clients upload to R2 first.
 */
export const mediaImageUrlSchema = z
  .string()
  .trim()
  .max(2048)
  .refine(
    (value) => /^https?:\/\//i.test(value) || MEDIA_REFERENCE_PATTERN.test(value),
    { message: "must be an absolute http(s) URL or a media:// asset reference" },
  );

/** Existing default-cover semantics: empty string, URL, or media reference. */
export const optionalMediaImageUrlSchema = z
  .union([z.literal(""), mediaImageUrlSchema])
  .optional();

export function isMediaReferenceValue(value: unknown): value is string {
  return typeof value === "string" && MEDIA_REFERENCE_PATTERN.test(value.trim());
}
