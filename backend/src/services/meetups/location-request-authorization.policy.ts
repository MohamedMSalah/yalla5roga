import type { Prisma } from "@prisma/client";
import { MeetupSessionRepository } from "../../repositories/meetups/meetup-session.repository.js";
import { LocationPrivacyRepository } from "../../repositories/users/location-privacy.repository.js";
import { isDeletedAccount } from "../users/account-deletion-access.js";
import { notificationPreferences } from "../notifications/notification-preferences.js";
import { ContextStartingLocationResolver } from "../users/context-starting-location-resolver.js";
import { ConflictError, ForbiddenError } from "../../utils/errors.js";

export function canRequestLocation(status: string) {
  return status === "STARTING_LOCATION_REQUIRED" || status === "CONSENT_REQUIRED";
}

export class LocationRequestAuthorizationPolicy {
  constructor(
    private readonly sessions = new MeetupSessionRepository(),
    private readonly privacy = new LocationPrivacyRepository(),
    private readonly locations = new ContextStartingLocationResolver(),
  ) {}

  async check(tx: Prisma.TransactionClient, sessionId: string, sender: string, target: string,
    now: Date, lock = false) {
    if (sender === target || isDeletedAccount(sender) || isDeletedAccount(target)) {
      throw new ForbiddenError("Choose another current group member");
    }
    const session = await this.sessions.get(tx, sessionId);
    const groupId = session.group_id;
    if (!groupId || session.session_type !== "GROUP") throw new ForbiddenError("Group meetup required");
    const members = lock
      ? await this.privacy.lockMemberships(tx, groupId, [sender, target])
      : await tx.group_members.findMany({
          where: { group_id: groupId, user_id: { in: [sender, target] } }, select: { user_id: true },
        });
    if (members.length !== 2) throw new ForbiddenError("Current group membership required");
    if (lock && session.outing_id) {
      await tx.$queryRaw`SELECT id FROM outings WHERE id = ${session.outing_id}::uuid FOR SHARE`;
    }
    if (lock) {
      await tx.$queryRaw`SELECT id FROM meetup_sessions WHERE id = ${sessionId}::uuid FOR SHARE`;
    }
    const current = lock ? await this.sessions.get(tx, sessionId) : session;
    const outing = session.outing_id ? await tx.outings.findUnique({
      where: { id: session.outing_id }, select: { group_id: true, status: true },
    }) : null;
    if (current.status !== "ACTIVE" || current.expires_at <= new Date() || (session.outing_id &&
        (outing?.group_id !== groupId || outing.status === "cancelled" || outing.status === "past"))) {
      throw new ConflictError("Meetup is closed");
    }
    const user = await tx.users.findUnique({
      where: { id: target }, select: {
        default_transportation_mode: true, location_privacy: true, notification_preferences: true,
        location_group_exclusions: { where: { group_id: groupId }, select: { group_id: true } },
      },
    });
    if (!user || user.location_group_exclusions.length) return { session, eligible: false };
    const prefs = notificationPreferences(user.notification_preferences);
    if (!prefs.pushEnabled || !prefs.groupEvents) return { session, eligible: false };
    const readiness = (await this.locations.resolveMany(tx, { kind: "meetup", id: session.id }, [{
      userId: target, accountMode: user.default_transportation_mode, privacy: user.location_privacy, excluded: false,
    }], now)).get(target);
    return { session, eligible: Boolean(readiness && canRequestLocation(readiness.status)) };
  }
}
