import { parsePhoneNumberFromString } from "libphonenumber-js";
import { ValidationError } from "../../utils/errors.js";

/** Numbers without a country code are treated as Egyptian, matching the app's phone length. */
const DEFAULT_REGION = "EG";

export function tryNormalizePhoneNumber(input: string): string | null {
  const compact = input.trim().replace(/[\s().-]/g, "");
  if (!/^\+?[0-9]+$/.test(compact)) return null;

  const parsed = parsePhoneNumberFromString(compact, DEFAULT_REGION);
  if (!parsed?.isValid()) return null;

  const e164 = parsed.number;
  if (!e164.startsWith("+") || e164.length > 16) return null;
  return e164;
}

export function normalizePhoneNumber(input: string): string {
  const phone = tryNormalizePhoneNumber(input);
  if (!phone) throw new ValidationError("Invalid phone number");
  return phone;
}
