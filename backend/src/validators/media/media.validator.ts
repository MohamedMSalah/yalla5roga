import { z } from "zod";

/** Purposes a client can request an upload for. */
export const mediaPurposeSchema = z.enum([
  "profile",
  "group",
  "outing",
  "place",
  "chat",
]);

const allowedMimeTypes = [
  "image/jpeg",
  "image/png",
  "image/webp",
  "image/gif",
];

export const requestUploadBodySchema = z
  .object({
    purpose: mediaPurposeSchema,
    mime_type: z.enum(allowedMimeTypes as [string, ...string[]]),
    file_size: z.number().int().positive().max(10 * 1024 * 1024),
    entity_id: z.uuid().optional().nullable(),
    /** Present = re-issue a fresh upload URL for a pending asset. */
    media_id: z.uuid().optional().nullable(),
  })
  .refine(
    (data) => !data.entity_id || data.purpose !== "profile",
    { path: ["entity_id"], message: "entity_id is not valid for profile uploads" },
  )
  .refine(
    (data) => data.purpose !== "chat" || Boolean(data.entity_id),
    {
      path: ["entity_id"],
      message: "entity_id (outing id) is required for chat uploads",
    },
  );

export const mediaIdParamsSchema = z.object({
  id: z.uuid(),
});

export const signedUrlsBodySchema = z.object({
  media_ids: z.array(z.uuid()).min(1).max(50),
});
