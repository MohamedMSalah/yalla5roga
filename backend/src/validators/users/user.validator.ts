import { z } from "zod";

/**
 * Called after Firebase sign-in, including phone, Google, and Apple.
 * Password is handled only by Firebase — never send it here.
 * Phone is optional. A value in this body does not prove ownership.
 */
export const syncUserBodySchema = z
  .object({
    name: z.string().trim().min(1).max(30),
    email: z.email().max(254),
    phoneNumber: z
      .string()
      .trim()
      .min(8)
      .max(20)
      .regex(/^\+?[0-9\s().-]+$/, "phoneNumber must be a valid phone number")
      .optional(),
    phone: z
      .string()
      .trim()
      .min(8)
      .max(20)
      .regex(/^\+?[0-9\s().-]+$/, "phone must be a valid phone number")
      .optional(),
    image_url: z.url().max(2048).optional().nullable(),
  })
  .transform((data) => ({
    name: data.name,
    email: data.email,
    phone: data.phoneNumber ?? data.phone ?? null,
    image_url: data.image_url ?? null,
  }));

export const updateUserBodySchema = z
  .object({
    name: z.string().trim().min(1).max(30).optional(),
    email: z.email().max(254).optional().nullable(),
    phoneNumber: z
      .string()
      .trim()
      .min(10)
      .max(13)
      .regex(/^\+?[0-9]+$/, "phoneNumber must be a valid phone number")
      .optional(),
    phone: z
      .string()
      .trim()
      .min(10)
      .max(13)
      .regex(/^\+?[0-9]+$/, "phone must be a valid phone number")
      .optional(),
    image_url: z.url().max(2048).optional().nullable(),
  })
  .transform((data) => ({
    name: data.name,
    email: data.email,
    phone: data.phoneNumber ?? data.phone,
    image_url: data.image_url,
  }));

export const userIdParamsSchema = z.object({
  id: z.string().min(1),
});
