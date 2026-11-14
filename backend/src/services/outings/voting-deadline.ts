import { ValidationError } from "../../utils/errors.js";

/** Resolve an explicit instant or legacy duration at the create boundary. */
export function resolveCreateVotingDeadline(input: {
  vote_ends_at?: Date | null;
  vote_deadline_hours?: number | null;
  scheduled_at?: Date | null;
}, now = new Date()): Date {
  const hours = input.vote_deadline_hours;
  if (hours != null && (!Number.isInteger(hours) || hours < 1 || hours > 168)) {
    throw new ValidationError("vote_deadline_hours must be between 1 and 168");
  }
  const deadline = input.vote_ends_at ?? (hours == null ? null : new Date(now.getTime() + hours * 3_600_000));
  if (!deadline) {
    throw new ValidationError("voting deadline is required: provide vote_ends_at or vote_deadline_hours");
  }
  if (!Number.isFinite(deadline.getTime()) || deadline.getTime() <= now.getTime()) {
    throw new ValidationError("vote_ends_at must be in the future");
  }
  if (input.scheduled_at && deadline.getTime() >= input.scheduled_at.getTime()) {
    throw new ValidationError("vote_ends_at must be before scheduled_at");
  }
  return deadline;
}
