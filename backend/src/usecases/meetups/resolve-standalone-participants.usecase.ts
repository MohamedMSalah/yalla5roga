
import type { Prisma } from "@prisma/client";
import { StandaloneMeetupRepository } from "../../repositories/meetups/standalone-meetup.repository.js";
import { summarizeMeetupReadiness } from "../../services/meetups/meetup-participant-resolver.js";
import { ContextStartingLocationResolver } from "../../services/users/context-starting-location-resolver.js";
import type { MeetupSession, StandaloneParticipant } from "../../types/meetups/meetup-session.js";

export class ResolveStandaloneParticipantsUseCase {
  constructor(
    private readonly repository = new StandaloneMeetupRepository(),
    private readonly locations = new ContextStartingLocationResolver(),
  ) {}

  async execute(tx: Prisma.TransactionClient, session: MeetupSession) {
    const uid = session.created_by_user_id;
    const owner = await tx.users.findUniqueOrThrow({ where: { id: uid },
      select: { default_transportation_mode: true, location_privacy: true },
    });
    const locations = await this.locations.resolveMany(tx, { kind: "meetup", id: session.id }, [{
      userId: uid, privacy: owner.location_privacy, excluded: false, accountMode: owner.default_transportation_mode,
    }], new Date());
    const location = locations.get(uid)!;
    const point = location.location?.point;
    const participants: StandaloneParticipant[] = [{
      id: session.id, participant_type: "OWNER", display_name: null,
      approximate_area: location.location?.district ?? null,
      latitude: point?.latitude ?? null, longitude: point?.longitude ?? null,
      transportation_mode: location.transportation.mode,
    }, ...(await this.repository.list(tx, session.id)).map(participant => ({
      ...participant, participant_type: "MANUAL" as const,
    }))];
    const readiness = summarizeMeetupReadiness(participants.map(participant => ({
      display_name: participant.display_name ?? (participant.participant_type === "OWNER" ? "You" : "Guest"),
      is_self: participant.participant_type === "OWNER",
      status: participant.latitude === null ? "SETUP_REQUIRED" : "READY",
      district: participant.approximate_area,
    })));
    return { participants, readiness, inputs: [location.dependency, participants] };
  }
}
