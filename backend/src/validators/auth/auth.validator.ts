import { z } from "zod";

const phoneSchema = z
  .string()
  .trim()
  .min(8)
  .max(20)
  .regex(/^\+?[0-9\s().-]+$/, "phone must be a valid phone number");

const passwordSchema = z.string().min(6).max(128);
const newPasswordSchema = passwordSchema.refine(
  (value) => Buffer.byteLength(value, "utf8") <= 72,
  "Password must be at most 72 UTF-8 bytes",
);

export const loginBodySchema = z.object({
  phone: phoneSchema,
  password: z.string().min(6).max(128),
});

export const changePasswordBodySchema = z.object({
  currentPassword: z.string().min(6).max(128),
  newPassword: newPasswordSchema,
});

export const verifyPasswordBodySchema = z.object({
  password: z.string().min(6).max(128),
});

export const signupBodySchema = z
  .object({
    name: z.string().trim().min(1).max(30),
    password: newPasswordSchema,
    phoneVerificationToken: z.string().trim().min(1).max(10000),
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
    phoneVerificationToken: data.phoneVerificationToken,
  }));

export const recoveryStartBodySchema = z.object({ phone: phoneSchema }).strict();
export const recoveryVerifyBodySchema = z.object({
  requestToken: z.string().regex(/^[A-Za-z0-9_-]{43}$/),
  phoneVerificationToken: z.string().min(1).max(10000),
}).strict();
export const resetPasswordBodySchema = z.object({
  resetToken: z.string().regex(/^[A-Za-z0-9_-]{43}$/),
  newPassword: newPasswordSchema.refine(value => value.length >= 8 && /[A-Z]/.test(value) && /[a-z]/.test(value) && /[0-9]/.test(value) && /[^A-Za-z0-9]/.test(value), "Use at least 8 characters, uppercase, lowercase, a number and a symbol"),
  confirmPassword: newPasswordSchema,
}).strict().refine(data => data.newPassword === data.confirmPassword, {
  message: "Passwords do not match", path: ["confirmPassword"],
});
