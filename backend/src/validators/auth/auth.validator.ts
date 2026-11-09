import { z } from "zod";

const phoneSchema = z
  .string()
  .trim()
  .min(8)
  .max(20)
  .regex(/^\+?[0-9\s().-]+$/, "phone must be a valid phone number");

export const loginBodySchema = z.object({
  phone: phoneSchema,
  password: z.string().min(6).max(128),
});

export const changePasswordBodySchema = z.object({
  currentPassword: z.string().min(6).max(128),
  newPassword: z.string().min(6).max(128),
});

export const verifyPasswordBodySchema = z.object({
  password: z.string().min(6).max(128),
});

export const signupBodySchema = z
  .object({
    name: z.string().trim().min(1).max(30),
    password: z.string().min(6).max(128),
    phoneNumber: phoneSchema.optional(),
    phone: phoneSchema.optional(),
  })
  .refine((data) => Boolean(data.phoneNumber ?? data.phone), {
    message: "phone is required",
    path: ["phone"],
  })
  .transform((data) => ({
    name: data.name,
    password: data.password,
    phone: (data.phoneNumber ?? data.phone) as string,
  }));
