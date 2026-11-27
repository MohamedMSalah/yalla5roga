import { randomUUID } from "node:crypto";
import { MeetupSessionRepository } from "../../repositories/meetups/meetup-session.repository.js";
import { LocationPrivacyRepository } from "../../repositories/users/location-privacy.repository.js";
import { LocationRequestAuthorizationPolicy } from "../../services/meetups/location-request-authorization.policy.js";
import { LocationRequestCooldownService } from "../../services/meetups/location-request-cooldown.service.js";
import { persistNotifications } from "../../services/notifications/persist-notification.js";
import { ForbiddenError } from "../../utils/errors.js";

export class RequestMemberLocationUseCase {
  constructor(
    private readonly privacy = new LocationPrivacyRepository(),
    private readonly policy = new LocationRequestAuthorizationPolicy(),
    private readonly cooldown = new LocationRequestCooldownService(),
    private readonly sessions = new MeetupSessionRepository(),
  ) {}

  execute(sender: string, sessionId: string, target: string) {
    return this.sessions.transaction(async tx => {
      // READ COMMITTED gives a fresh outbox snapshot after acquiring both sorted
      // user locks, even when a concurrent request was queued ahead of this one.
      if (sender === target || (await this.privacy.lockUsers(tx, [sender, target], true)).length !== 2) {
        throw new ForbiddenError("Choose another current group member");
      }
      const now = new Date();
      const { session, eligible } = await this.policy.check(tx, sessionId, sender, target, now, true);
      if (!eligible) return { status: "UNAVAILABLE", retry_at: null } as const;
      const retryAt = await this.cooldown.retryAt(tx, sender, target, now);
      if (retryAt) return { status: "COOLDOWN", retry_at: retryAt } as const;

      const expiresAt = new Date(Math.min(session.expires_at.getTime(), now.getTime() + 86_400_000));
      await persistNotifications(tx, {
        recipients: [target], eventKey: `meetup_location_requested:${randomUUID()}`,
        eventType: "meetup_location_requested", type: "system",
        title: "Smart Meetup location request",
        body: "A group member asked you to set up your starting location for Smart Meetup.",
        groupId: session.group_id, outingId: session.outing_id, actionRequired: true, createdAt: now,
        data: { sessionId, requesterId: sender, requestedAt: now.toISOString(), expiresAt: expiresAt.toISOString(),
          deepLink: `/notification/smart-meetups/${sessionId}/my-starting-location` },
      });
      return { status: "REQUESTED", retry_at: null } as const;
    }, "ReadCommitted");
  }
}
