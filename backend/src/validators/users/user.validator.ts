import { z } from "zod";
import { tryNormalizePhoneNumber } from "../../services/phone/normalize-phone.js";

const optionalPhoneField = z
  .string()
  .trim()
  .min(8)
  .max(20)
  .regex(/^\+?[0-9\s().-]+$/, "must be a valid phone number")
  .optional();

const optionalUpdatePhoneField = z
  .string()
  .trim()
  .min(10)
  .max(13)
  .regex(/^\+?[0-9]+$/, "must be a valid phone number")
  .optional();

/**
 * phone and phoneNumber are aliases. Prefer a single field; if both are sent
 * they must normalize to the same E.164 value.
 */
function refinePhoneAliases(
  data: { phone?: string; phoneNumber?: string },
  ctx: z.RefinementCtx,
) {
  if (data.phone == null || data.phoneNumber == null) return;

  const fromPhone = tryNormalizePhoneNumber(data.phone);
  const fromPhoneNumber = tryNormalizePhoneNumber(data.phoneNumber);

  if (!fromPhone || !fromPhoneNumber || fromPhone !== fromPhoneNumber) {
    ctx.addIssue({
      code: "custom",
      path: ["phone"],
      message: "phone and phoneNumber must match",
    });
  }
}

/**
 * Called after Firebase sign-in, including phone, Google, and Apple.
 * Email/password credentials live in Neon via /api/auth — never send a password here.
 *
 * All body fields are optional and deprecated for overwriting an existing
 * profile. On first sync they may bootstrap a minimal row. Identity (UID,
 * verified phone, provider) always comes from the Bearer token.
 */
export const syncUserBodySchema = z.preprocess(
  (value) => (value == null || typeof value !== "object" ? {} : value),
  z
    .object({
      // Longer provider display names are truncated to 30 before insert.
      name: z.string().trim().min(1).max(200).optional(),
      phoneNumber: optionalPhoneField,
      phone: optionalPhoneField,
      image_url: z.url().max(2048).optional().nullable(),
      phoneVerificationToken: z.string().trim().min(1).max(10000).optional(),
    })
    .superRefine(refinePhoneAliases)
    .transform((data) => ({
      name: data.name,
      phone: data.phoneNumber ?? data.phone ?? null,
      image_url: data.image_url ?? null,
      ...(data.phoneVerificationToken ? { phoneVerificationToken: data.phoneVerificationToken } : {}),
    })),
);

export const updateUserBodySchema = z
  .object({
    name: z.string().trim().min(1).max(30).optional(),
    phoneNumber: optionalUpdatePhoneField,
    phone: optionalUpdatePhoneField,
    image_url: z.url().max(2048).optional().nullable(),
  })
  .superRefine(refinePhoneAliases)
  .transform((data) => ({
    name: data.name,
    phone: data.phoneNumber ?? data.phone,
    image_url: data.image_url,
  }));

export const userIdParamsSchema = z.object({
  id: z.string().min(1),
});
