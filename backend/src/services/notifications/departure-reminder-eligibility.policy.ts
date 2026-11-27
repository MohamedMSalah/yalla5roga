import { createHash } from "node:crypto";
import type { Prisma } from "@prisma/client";
import { DepartureReminderRepository } from "../../repositories/notifications/departure-reminder.repository.js";
import type { TrustedTravelEstimate, TrustedTravelEstimateInputs } from "../../types/routing/trusted-travel-estimate.js";
import { GetEffectiveStartingLocationUseCase } from "../../usecases/users/starting-location-override.usecases.js";
import { ForbiddenError, NotFoundError } from "../../utils/errors.js";
import { notificationPreferences } from "./notification-preferences.js";

export const fingerprint = (values: unknown) => createHash("sha256").update(JSON.stringify(values)).digest("hex");

export class DepartureReminderEligibilityPolicy {
  constructor(
    private readonly repository = new DepartureReminderRepository(),
    private readonly startingLocation = new GetEffectiveStartingLocationUseCase(),
  ) {}

  async requireAccess(tx: Prisma.TransactionClient, uid: string, outingId: string, lockOuting = false) {
    if (lockOuting) {
      await tx.$queryRaw`SELECT id FROM outings WHERE id = ${outingId}::uuid FOR SHARE`;
      await tx.$queryRaw`SELECT outing_id FROM outing_attendance WHERE outing_id = ${outingId}::uuid
        AND user_id = ${uid} FOR SHARE`;
      await tx.$queryRaw`SELECT p.id FROM places p INNER JOIN outings o ON o.location_place_id = p.id
        WHERE o.id = ${outingId}::uuid FOR SHARE OF p`;
    }
    const outing = await tx.outings.findUnique({
      where: { id: outingId },
      include: {
        groups: { select: { group_members: { where: { user_id: uid }, select: { user_id: true } } } },
        outing_guests: { where: { user_id: uid, status: "accepted" }, select: { user_id: true } },
        outing_attendance: { where: { user_id: uid }, select: { status: true } },
        places: { select: { id: true, latitude: true, longitude: true, status: true, is_active: true } },
      },
    });
    if (!outing) throw new NotFoundError("Outing");
    if (outing.created_by !== uid && !outing.groups?.group_members.length && !outing.outing_guests.length) {
      throw new ForbiddenError("Current outing access required");
    }
    return outing;
  }

  async resolve(tx: Prisma.TransactionClient, uid: string, outingId: string, now: Date) {
    const outing = await this.requireAccess(tx, uid, outingId, true);
    const preferences = await this.repository.preferences(tx, uid);
    const account = await tx.users.findUniqueOrThrow({ where: { id: uid }, select: { notification_preferences: true } });
    const notifications = notificationPreferences(account.notification_preferences);
    const start = outing.scheduled_at;
    const canReadLocation = start && start > now && (!outing.ends_at || outing.ends_at > now) &&
      outing.status === "confirmed";
    const starting = canReadLocation ? await this.startingLocation.read(tx, uid, { kind: "outing", id: outingId }) : null;
    const effective = starting?.effective;
    const location = effective?.location;
    const mode = effective?.transportation.mode ?? null;
    const starting_location = location ? { name: location.name, name_ar: location.name_ar, temporary: location.temporary } : null;
    const view = { ...preferences, starting_location, transportation_mode: mode };
    const hasSnapshot = outing.location_latitude != null && outing.location_longitude != null;
    const lat = hasSnapshot ? outing.location_latitude : outing.places?.latitude;
    const lon = hasSnapshot ? outing.location_longitude : outing.places?.longitude;
    const validVenue = lat != null && lon != null && Math.abs(lat) <= 90 && Math.abs(lon) <= 180 &&
      (!outing.places || (outing.places.is_active && outing.places.status === "active"));
    const reason = !canReadLocation || !validVenue ? "OUTING_UNAVAILABLE"
      : outing.outing_attendance[0]?.status !== "going" ? "RSVP_REQUIRED"
      : !preferences.enabled ? "OPT_IN_REQUIRED"
      : !notifications.pushEnabled || !notifications.reminders ? "NOTIFICATIONS_DISABLED"
      : !location ? "STARTING_LOCATION_REQUIRED"
      : !mode ? "TRANSPORTATION_MODE_REQUIRED"
      : null;
    if (reason || !effective || !location || !mode || !start) {
      return { view, reason: reason ?? "OUTING_UNAVAILABLE", start: null, inputs: null };
    }
    const inputs: TrustedTravelEstimateInputs = {
      userId: uid, outingId, transportationMode: mode,
      venueVersion: fingerprint([outingId, outing.location_place_id, lat, lon]),
      startingLocationVersion: fingerprint([uid, effective.input_version, starting?.dependency]),
      outingScheduleVersion: fingerprint([outingId, start, outing.ends_at]),
    };
    return { view, reason: null, start, inputs };
  }

  matches(estimate: TrustedTravelEstimate, inputs: TrustedTravelEstimateInputs, now: Date) {
    return Object.entries(inputs).every(([key, value]) => estimate[key as keyof TrustedTravelEstimate] === value) &&
      estimate.reference.length > 0 && estimate.reference.length <= 128 &&
      Number.isSafeInteger(estimate.durationSeconds) && estimate.durationSeconds >= 0 && estimate.durationSeconds <= 7 * 86_400 &&
      estimate.calculatedAt <= now && now.getTime() - estimate.calculatedAt.getTime() <= 15 * 60_000 &&
      estimate.expiresAt > now;
  }
}
