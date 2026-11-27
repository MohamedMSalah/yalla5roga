import { DepartureReminderRepository, type DepartureReminderPreferencePatch } from "../../repositories/notifications/departure-reminder.repository.js";
import { LocationPrivacyRepository } from "../../repositories/users/location-privacy.repository.js";
import { DepartureReminderEligibilityPolicy, fingerprint } from "../../services/notifications/departure-reminder-eligibility.policy.js";
import type { TrustedTravelEstimateSource } from "../../types/routing/trusted-travel-estimate.js";
import { NotFoundError } from "../../utils/errors.js";

export class GetDepartureReminderPreferencesUseCase {
  constructor(private readonly repository = new DepartureReminderRepository()) {}
  execute(uid: string) {
    return this.repository.transaction(tx => this.repository.preferences(tx, uid));
  }
}

export class UpdateDepartureReminderPreferencesUseCase {
  constructor(private readonly repository = new DepartureReminderRepository(), private readonly users = new LocationPrivacyRepository()) {}
  execute(uid: string, patch: DepartureReminderPreferencePatch) {
    return this.repository.transaction(async tx => {
      if (!(await this.users.lockUsers(tx, [uid], true)).length) throw new NotFoundError("User");
      const current = await this.repository.preferences(tx, uid);
      if (Object.entries(patch).every(([key, value]) => current[key as keyof typeof current] === value)) return current;
      return this.repository.savePreferences(tx, uid, patch);
    });
  }
}

export class ScheduleDepartureReminderUseCase {
  constructor(
    private readonly repository = new DepartureReminderRepository(),
    private readonly policy = new DepartureReminderEligibilityPolicy(repository),
    // No source is registered until a trusted backend routing integration exists.
    private readonly estimates?: TrustedTravelEstimateSource,
    private readonly users = new LocationPrivacyRepository(),
  ) {}

  execute(uid: string, outingId: string, schedule: boolean) {
    return this.repository.transaction(async tx => {
      if (!(await this.users.lockUsers(tx, [uid], schedule)).length) throw new NotFoundError("User");
      const now = new Date();
      const { view, reason, start, inputs } = await this.policy.resolve(tx, uid, outingId, now);
      const unavailable = (code: string) => ({
        ...view, status: code, estimated_journey_seconds: null, suggested_departure_at: null, scheduled_send_at: null,
      });
      if (!inputs || !start || reason) return unavailable(reason ?? "OUTING_UNAVAILABLE");
      if (!this.estimates) return unavailable("ROUTING_UNAVAILABLE");

      const inputFingerprint = fingerprint([inputs, view.preparation_buffer_minutes]);
      const current = await this.repository.current(tx, outingId, uid);
      if (current?.status === "sent") return unavailable("ALREADY_SENT");
      if (!schedule && current?.input_fingerprint === inputFingerprint && current.scheduled_send_at > now) {
        return {
          ...view, status: "SCHEDULED", estimated_journey_seconds: current.duration_seconds,
          suggested_departure_at: new Date(start.getTime() - current.duration_seconds * 1000),
          scheduled_send_at: current.scheduled_send_at,
        };
      }

      const estimate = await this.estimates.find(inputs);
      const checkedAt = new Date();
      if (!estimate || !this.policy.matches(estimate, inputs, checkedAt)) return unavailable("ESTIMATE_UNAVAILABLE");
      const departure = new Date(start.getTime() - estimate.durationSeconds * 1000);
      const sendAt = new Date(departure.getTime() - view.preparation_buffer_minutes * 60_000);
      if (sendAt <= checkedAt) {
        if (schedule && current) await this.repository.clear(tx, outingId, uid);
        return unavailable("DEPARTURE_PASSED");
      }
      if (schedule) await this.repository.save(tx, outingId, uid, {
        scheduled_send_at: sendAt, estimate_reference: estimate.reference, input_fingerprint: inputFingerprint,
        deduplication_key: fingerprint(["departure", inputFingerprint]), duration_seconds: estimate.durationSeconds,
      });
      return {
        ...view, status: schedule ? "SCHEDULED" : "AVAILABLE", estimated_journey_seconds: estimate.durationSeconds,
        suggested_departure_at: departure, scheduled_send_at: schedule ? sendAt : null,
      };
    });
  }
}

export class InvalidateDepartureReminderUseCase {
  constructor(
    private readonly repository = new DepartureReminderRepository(),
    private readonly policy = new DepartureReminderEligibilityPolicy(repository),
    private readonly users = new LocationPrivacyRepository(),
  ) {}
  execute(uid: string, outingId: string) {
    return this.repository.transaction(async tx => {
      if (!(await this.users.lockUsers(tx, [uid], true)).length) throw new NotFoundError("User");
      await this.policy.requireAccess(tx, uid, outingId, true);
      await this.repository.clear(tx, outingId, uid);
      return null;
    });
  }
}
