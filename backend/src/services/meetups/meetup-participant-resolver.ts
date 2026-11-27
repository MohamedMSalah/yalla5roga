
import { createHash } from "node:crypto";
import type { Prisma } from "@prisma/client";
import type { MeetupPreferences } from "../../types/meetups/meetup-preferences.js";
import type { MeetupReadinessSummary, MeetupSession, ParticipantReadiness } from "../../types/meetups/meetup-session.js";
import { canRequestLocation } from "./location-request-authorization.policy.js";
import { isDeletedAccount } from "../users/account-deletion-access.js";
import { ContextStartingLocationResolver } from "../users/context-starting-location-resolver.js";

export function summarizeMeetupReadiness(participants: ParticipantReadiness[]): MeetupReadinessSummary {
  const intended = participants.length;
  const usable = participants.filter(member => member.status === "READY").length;
  return { intended, usable, requiring_setup: intended - usable,
    status: usable === 0 ? "INSUFFICIENT_DATA" : usable === intended ? "READY" : "PARTIAL", participants };
}

export class MeetupInputVersionService {
  digest(sessionId: string, preferences: MeetupPreferences, inputs: unknown[]) {
    return createHash("sha256").update(JSON.stringify([sessionId, preferences, inputs])).digest("hex");
  }
}

export class MeetupParticipantResolver {
  constructor(private readonly locations = new ContextStartingLocationResolver()) {}

  async resolve(tx: Prisma.TransactionClient, session: MeetupSession, requester: string) {
    const groupId = session.group_id!;
    const members = await tx.group_members.findMany({
      where: { group_id: groupId }, orderBy: { user_id: "asc" },
      select: { user_id: true, joined_at: true, users: { select: {
        name: true, default_transportation_mode: true, location_privacy: true,
        location_group_exclusions: { where: { group_id: groupId }, select: { group_id: true } },
      } } },
    });
    const locations = await this.locations.resolveMany(tx, { kind: "meetup", id: session.id },
      members.map(({ user_id, users }) => ({
        userId: user_id, privacy: users.location_privacy,
        excluded: users.location_group_exclusions.length > 0, accountMode: users.default_transportation_mode,
      })), new Date(),
    );
    const inputs = [];
    const participants: ParticipantReadiness[] = [];
    for (const { users, user_id, joined_at } of members) {
      const location = locations.get(user_id)!;
      inputs.push([user_id, joined_at, location.dependency]);
      participants.push({
        display_name: users.name.replace(/[\p{Cc}\u202a-\u202e\u2066-\u2069]/gu, "").trim() || "Member",
        is_self: user_id === requester,
        status: location.location ? "READY" : "SETUP_REQUIRED", district: location.district,
        ...(user_id !== requester && !isDeletedAccount(user_id) && canRequestLocation(location.status) && { request_target_user_id: user_id }),
      });
    }
    return { inputs, readiness: summarizeMeetupReadiness(participants) };
  }
}
