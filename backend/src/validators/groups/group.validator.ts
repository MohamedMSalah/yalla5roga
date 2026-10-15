import { z } from "zod";

export const createGroupBodySchema = z.object({
  name: z.string().trim().min(1).max(30),
  bio: z.string().trim().max(160).optional(),
  image_url: z.url().max(2048),
});

export const updateGroupBodySchema = z.object({
  name: z.string().trim().min(1).max(30).optional(),
  bio: z.string().trim().max(160).optional(),
  image_url: z.url().max(2048).optional(),
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
  role: z.enum(["owner", "member"]).optional(),
});

export const groupMemberParamsSchema = z.object({
  id: z.uuid(),
  userId: z.string().min(1),
});

export const inviteToGroupBodySchema = z.object({
  phoneNumber: z.string().trim().min(8).max(20),
});
