import type { Prisma } from "@prisma/client";
import { LocationPrivacyRepository } from "../../repositories/users/location-privacy.repository.js";
import type { SharedStartingArea, StartingPoint } from "../../types/users/location-privacy.types.js";
import { ForbiddenError, NotFoundError } from "../../utils/errors.js";
import { LocationPrivacyPolicy } from "./location-privacy-policy.js";

type MemberAuthorization = Readonly<{
  userId: string;
  joined: string;
  revision: string;
}>;

/** Coordinate-free dependency of a session, result, cache entry or reminder. Keep it server-side. */
export type LocationAuthorization = Readonly<{
  groupId: string;
  requesterId: string;
  requesterJoined: string;
  members: readonly MemberAuthorization[];
}>;

export type AuthorizedStartingLocations =
  | { status: "READY"; points: ReadonlyMap<string, StartingPoint>; authorization: LocationAuthorization }
  | { status: "MEMBERSHIP_REQUIRED" | "CONSENT_REQUIRED" | "GROUP_EXCLUDED" | "STARTING_LOCATION_REQUIRED"; userId: string };

export class LocationUsageAuthorizationService {
  constructor(
    private readonly repository = new LocationPrivacyRepository(),
    private readonly policy = new LocationPrivacyPolicy(),
  ) {}

  private async lockScope(tx: Prisma.TransactionClient, groupId: string, requesterId: string, users: readonly string[]) {
    const ids = [...new Set([requesterId, ...users])];
    await this.repository.lockUsers(tx, ids);
    await this.repository.lockGroup(tx, groupId);
    const rows = await this.repository.lockMemberships(tx, groupId, ids);
    return new Map(rows.map(({ user_id, joined }) => [user_id, joined]));
  }

  sharedArea(groupId: string, requesterId: string, subjectId: string): Promise<SharedStartingArea> {
    return this.repository.transaction(async (tx) => {
      const members = await this.lockScope(tx, groupId, requesterId, [subjectId]);
      if (!members.has(requesterId)) throw new ForbiddenError("Current group membership required");
      if (!members.has(subjectId)) throw new NotFoundError("Group member");
      const privacy = await this.repository.get(tx, subjectId);
      const district = this.policy.isHidden(privacy) ? null : await this.repository.getDistrict(tx, subjectId);
      return this.policy.sharedArea(privacy, district);
    });
  }

  private async authorization(tx: Prisma.TransactionClient, userId: string, groupId: string) {
    const privacy = await this.repository.get(tx, userId);
    if (!this.policy.hasValidConsent(privacy)) return { status: "CONSENT_REQUIRED" } as const;
    if (await this.repository.getExclusion(tx, userId, groupId)) return { status: "GROUP_EXCLUDED" } as const;
    return { status: "READY", revision: privacy.authorization_revision } as const;
  }

  /** Call at calculation start. Use points in memory and retain only the coordinate-free authorization. */
  resolveForCalculation(groupId: string, requesterId: string, subjectIds: readonly string[]): Promise<AuthorizedStartingLocations> {
    const ids = [...new Set(subjectIds)];
    return this.repository.transaction(async (tx) => {
      const memberships = await this.lockScope(tx, groupId, requesterId, ids);
      const requesterJoined = memberships.get(requesterId);
      if (requesterJoined === undefined) throw new ForbiddenError("Current group membership required");
      const members: MemberAuthorization[] = [];
      for (const userId of ids) {
        const joined = memberships.get(userId);
        if (joined === undefined) return { status: "MEMBERSHIP_REQUIRED", userId };
        const current = await this.authorization(tx, userId, groupId);
        if (current.status !== "READY") return { status: current.status, userId };
        members.push({ userId, joined, revision: current.revision });
      }
      const points = new Map<string, StartingPoint>();
      for (const { userId } of members) {
        const point = this.policy.startingPoint(await this.repository.getStartingPoint(tx, userId));
        if (!point) return { status: "STARTING_LOCATION_REQUIRED", userId };
        points.set(userId, point);
      }
      return { status: "READY", points, authorization: { groupId, requesterId, requesterJoined, members } };
    });
  }

  /**
   * Gate publication, result/cache reads and reminder work with this transaction.
   * Revisions prevent a later re-grant or removal of an exclusion from reviving old work.
   */
  withCurrentAuthorization<T>(
    proof: LocationAuthorization,
    requesterId: string,
    run: (tx: Prisma.TransactionClient) => Promise<T>,
  ): Promise<{ authorized: false } | { authorized: true; result: T }> {
    const { groupId, members } = proof;
    return this.repository.transaction(async (tx) => {
      const memberships = await this.lockScope(tx, groupId, requesterId, [
        proof.requesterId, ...members.map(({ userId }) => userId),
      ]);
      if (!memberships.has(requesterId) || memberships.get(proof.requesterId) !== proof.requesterJoined) {
        return { authorized: false };
      }
      for (const { userId, joined, revision } of members) {
        if (memberships.get(userId) !== joined) return { authorized: false };
        const current = await this.authorization(tx, userId, groupId);
        if (current.status !== "READY" || current.revision !== revision) return { authorized: false };
      }
      return { authorized: true, result: await run(tx) };
    });
  }
}
