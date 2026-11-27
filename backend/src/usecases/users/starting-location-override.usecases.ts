import type { Prisma } from "@prisma/client";
import { MeetupSessionAuthorizationPolicy, MeetupSessionRepository } from "../../repositories/meetups/meetup-session.repository.js";
import { StandaloneMeetupAuthorizationPolicy } from "../../repositories/meetups/standalone-meetup.repository.js";
import { LocationPrivacyRepository } from "../../repositories/users/location-privacy.repository.js";
import { StartingLocationOverrideRepository } from "../../repositories/users/starting-location-override.repository.js";
import { ContextStartingLocationResolver } from "../../services/users/context-starting-location-resolver.js";
import {
  startingLocationContextConsentVersion, type StartingLocationContext, type StartingLocationOverrideInput,
} from "../../types/users/starting-location-override.js";
import { ConflictError, ForbiddenError, NotFoundError } from "../../utils/errors.js";

const sixHours = 6 * 60 * 60 * 1000;

class StartingLocationOverrideUseCase {
  constructor(
    protected readonly repository = new StartingLocationOverrideRepository(),
    private readonly resolver = new ContextStartingLocationResolver(repository),
    private readonly privacy = new LocationPrivacyRepository(),
    private readonly sessions = new MeetupSessionRepository(),
    private readonly meetupPolicy = new MeetupSessionAuthorizationPolicy(),
    private readonly standalonePolicy = new StandaloneMeetupAuthorizationPolicy(),
  ) {}

  private async outing(tx: Prisma.TransactionClient, id: string) {
    const outing = await tx.outings.findUnique({ where: { id }, select: {
      id: true, created_by: true, group_id: true, status: true,
      scheduled_at: true, ends_at: true,
    } });
    if (!outing) throw new NotFoundError("Outing");
    return outing;
  }

  private outingExpiry(outing: Awaited<ReturnType<StartingLocationOverrideUseCase["outing"]>>) {
    if (outing.status === "past" || outing.status === "cancelled") throw new ConflictError("Outing is closed");
    return outing.ends_at ?? (outing.scheduled_at && new Date(outing.scheduled_at.getTime() + sixHours));
  }

  protected async scope(tx: Prisma.TransactionClient, userId: string, context: StartingLocationContext) {
    // Serialize permission changes with writes, using the privacy repository's lock order.
    if (!(await this.privacy.lockUsers(tx, [userId])).length) throw new NotFoundError("User");
    let groupId: string | null;
    let expiresAt: Date;
    if (context.kind === "meetup") {
      const session = await this.sessions.get(tx, context.id);
      groupId = session.group_id;
      if (session.session_type === "STANDALONE") {
        this.standalonePolicy.requireOwner(session, userId);
      } else {
        await this.meetupPolicy.requireMember(tx, groupId!, userId);
        if (!(await this.privacy.lockMemberships(tx, groupId!, [userId])).length) {
          throw new ForbiddenError("Current group membership required");
        }
      }
      if (session.status !== "ACTIVE") throw new ConflictError("Meetup is closed");
      expiresAt = session.expires_at;
      if (session.outing_id) {
        const end = this.outingExpiry(await this.outing(tx, session.outing_id));
        if (end && end < expiresAt) expiresAt = end;
      }
    } else {
      const outing = await this.outing(tx, context.id);
      groupId = outing.group_id;
      if (outing.created_by !== userId) {
        const member = groupId && (await this.privacy.lockMemberships(tx, groupId, [userId])).length;
        if (!member) {
          const [guest] = await tx.$queryRaw<Array<{ user_id: string }>>`
            SELECT user_id FROM outing_guests
            WHERE outing_id = ${outing.id}::uuid AND user_id = ${userId} AND status = 'accepted'
            FOR SHARE
          `;
          if (!guest) throw new ForbiddenError("Accepted outing participation required");
        }
      }
      const end = this.outingExpiry(outing);
      if (!end) throw new ConflictError("Outing has no scheduled time");
      expiresAt = end;
    }
    const now = new Date();
    if (expiresAt <= now) throw new ConflictError("Starting location context has expired");
    const owner = await tx.users.findUniqueOrThrow({ where: { id: userId }, select: {
      location_privacy: true, default_transportation_mode: true,
    } });
    const excluded = groupId !== null && Boolean(await this.privacy.getExclusion(tx, userId, groupId));
    return { now, expiresAt, owner: { userId, excluded, privacy: owner.location_privacy,
      accountMode: owner.default_transportation_mode } };
  }

  protected async effective(tx: Prisma.TransactionClient, context: StartingLocationContext,
    scope: Awaited<ReturnType<StartingLocationOverrideUseCase["scope"]>>) {
    const { owner, now } = scope;
    const effective = (await this.resolver.resolveMany(tx, context, [owner], now)).get(owner.userId)!;
    const { location, temporary, transportation, override } = effective;
    const version = context.kind === "meetup"
      ? (await tx.meetup_sessions.findUniqueOrThrow({ where: { id: context.id },
          select: { input_version: true } })).input_version
      : (await tx.outings.findUniqueOrThrow({ where: { id: context.id },
          select: { travel_input_version: true } })).travel_input_version;
    return {
      dependency: effective.dependency,
      view: {
        status: effective.status,
        location: location && { ...location.point, name: location.name, name_ar: location.name_ar, temporary },
        transportation,
        override: override && {
          location_source: override.location_source,
          personal_location_id: override.personal_location_id, saved_place_id: override.saved_place_id,
          latitude: override.latitude, longitude: override.longitude, transportation_mode: override.transportation_mode,
          expires_at: override.expires_at < scope.expiresAt ? override.expires_at : scope.expiresAt,
        },
        input_version: version,
        consent_policy_version: startingLocationContextConsentVersion,
      },
    };
  }
}

export class GetEffectiveStartingLocationUseCase extends StartingLocationOverrideUseCase {
  execute(userId: string, context: StartingLocationContext) {
    return this.repository.transaction(async tx => (await this.read(tx, userId, context)).effective);
  }

  async read(tx: Prisma.TransactionClient, userId: string, context: StartingLocationContext) {
    const scope = await this.scope(tx, userId, context);
    const { view, dependency } = await this.effective(tx, context, scope);
    return { effective: view, dependency, expiresAt: scope.expiresAt };
  }
}

export class SetStartingLocationOverrideUseCase extends StartingLocationOverrideUseCase {
  execute(userId: string, context: StartingLocationContext, input: StartingLocationOverrideInput) {
    return this.repository.transaction(async tx => {
      const scope = await this.scope(tx, userId, context);
      if (scope.owner.excluded) throw new ForbiddenError("Starting location use is excluded for this group");
      if ((input.location_source !== "DEFAULT" || input.consent_policy_version !== undefined) &&
          input.consent_policy_version !== startingLocationContextConsentVersion) {
        throw new ConflictError("Read and accept the current temporary location usage policy");
      }
      if (input.location_source === "PERSONAL_LOCATION" &&
          !await this.repository.personal(tx, userId, input.personal_location_id)) {
        throw new NotFoundError("Personal location");
      }
      if (input.location_source === "SAVED_PLACE") {
        const saved = await this.repository.bookmark(tx, userId, input.saved_place_id);
        if (!saved) throw new NotFoundError("Saved place");
        if (!saved.places.is_active || saved.places.status !== "active" ||
            saved.places.latitude === null || saved.places.longitude === null ||
            Math.abs(saved.places.latitude) > 90 || Math.abs(saved.places.longitude) > 180) {
          throw new ConflictError("Saved place coordinates are unavailable");
        }
      }
      await this.repository.set(tx, userId, context, input, scope.expiresAt, scope.now);
      return (await this.effective(tx, context, scope)).view;
    });
  }
}

export class ClearStartingLocationOverrideUseCase extends StartingLocationOverrideUseCase {
  execute(userId: string, context: StartingLocationContext) {
    return this.repository.transaction(async tx => {
      const scope = await this.scope(tx, userId, context);
      await this.repository.clear(tx, userId, context);
      return (await this.effective(tx, context, scope)).view;
    });
  }
}
