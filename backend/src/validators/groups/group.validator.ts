import { z } from "zod";
import { optionalMediaImageUrlSchema } from "../media/image-url.validator.js";

/** Empty string is allowed and stored as the DB default cover. */
const optionalImageUrl = optionalMediaImageUrlSchema;

export const createGroupBodySchema = z.object({
  name: z.string().trim().min(3).max(30),
  bio: z.string().trim().max(160).optional(),
  image_url: optionalImageUrl,
});

export const updateGroupBodySchema = z.object({
  name: z.string().trim().min(3).max(30).optional(),
  bio: z.string().trim().max(160).optional(),
  image_url: optionalImageUrl,
});

export const groupIdParamsSchema = z.object({
  id: z.uuid(),
});

export const listGroupsQuerySchema = z.object({
  userId: z.string().min(1).optional(),
});

export const addGroupMemberBodySchema = z.object({
  phoneNumber: z
    .string()
    .trim()
    .min(10)
    .max(13)
    .regex(/^\+?[0-9]+$/, "phoneNumber must be a valid phone number"),
  role: z.enum(["member"]).optional(),
});

export const groupMemberParamsSchema = z.object({
  id: z.uuid(),
  userId: z.string().min(1),
});

export const inviteToGroupBodySchema = z.object({
  whatsappOptIn: z.boolean().optional(),
  phoneNumber: z.string().trim().min(8).max(20),
});

export const pendingMembershipParamsSchema = z.object({
  id: z.uuid(),
  invitationId: z.uuid(),
});

export const invitationIdParamsSchema = z.object({
  invitationId: z.uuid(),
});
