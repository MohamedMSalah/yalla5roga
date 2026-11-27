import type { meetup_sessions, meetup_calculation_status, Prisma, transportation_mode } from "@prisma/client";
import type { MeetupPreferences } from "./meetup-preferences.js";

export type MeetupSession = meetup_sessions;
export type StandaloneParticipant = {
  id: string;
  participant_type: "OWNER" | "MANUAL";
  display_name: string | null;
  approximate_area: string | null;
  latitude: number | null;
  longitude: number | null;
  transportation_mode: transportation_mode | null;
};
export type ParticipantReadiness = {
  display_name: string;
  is_self: boolean;
  status: "READY" | "SETUP_REQUIRED";
  district: string | null;
  request_target_user_id?: string;
};

export interface MeetupReadinessSummary {
  intended: number;
  usable: number;
  requiring_setup: number;
  status: "READY" | "PARTIAL" | "INSUFFICIENT_DATA";
  participants: ParticipantReadiness[];
}

/** Implementations enqueue idempotently by session and input version in this transaction.
 * Workers must re-resolve location authorization before calculation and publication.
 */
export interface MeetupCalculationCoordinator {
  prepare(tx: Prisma.TransactionClient, sessionId: string, version: number,
    readiness: Pick<MeetupReadinessSummary, "intended" | "usable">,
    preferences: MeetupPreferences): Promise<meetup_calculation_status>;
}

export const routingUnavailable: MeetupCalculationCoordinator = {
  async prepare() { return "ROUTING_UNAVAILABLE"; },
};
