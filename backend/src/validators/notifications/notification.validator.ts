import { z } from "zod";

export const notificationIdParamsSchema = z.object({
  id: z.uuid(),
});

/** Bounded inbox; opaque cursor from the preceding page. */
export const listNotificationsQuerySchema = z.object({
  limit: z.coerce.number().int().min(1).max(100).default(20),
  cursor: z.string().min(1).max(512).optional(),
});
