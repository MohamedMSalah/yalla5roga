import { ValidationError } from "../../utils/errors.js";

/**
 * Mirrors the database rule chk_outings_end_after_start so the client gets a
 * 400 with a readable message instead of a constraint error.
 */
export function assertEndsAfterStart(
  scheduledAt: Date | null | undefined,
  endsAt: Date | null | undefined,
): void {
  if (!scheduledAt || !endsAt) return;
  if (endsAt.getTime() <= scheduledAt.getTime()) {
    throw new ValidationError("ends_at must be later than scheduled_at");
  }
}
