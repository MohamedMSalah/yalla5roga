import { z } from "zod";

export const outingIdParamsSchema = z.object({
  outingId: z.uuid(),
});

export const sendMessageBodySchema = z.object({
  text: z.string().trim().min(1).max(2000),
});
