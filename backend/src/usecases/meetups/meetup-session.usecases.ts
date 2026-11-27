import type { Prisma } from "@prisma/client";
import { MeetupPreferencesRepository } from "../../repositories/meetups/meetup-preferences.repository.js";
import { MeetupSessionAuthorizationPolicy, MeetupSessionRepository } from "../../repositories/meetups/meetup-session.repository.js";
import { StandaloneMeetupAuthorizationPolicy, StandaloneMeetupRepository } from "../../repositories/meetups/standalone-meetup.repository.js";
import { MeetupInputVersionService, MeetupParticipantResolver } from "../../services/meetups/meetup-participant-resolver.js";
import { routingUnavailable, type MeetupCalculationCoordinator, type MeetupReadinessSummary, type MeetupSession, type StandaloneParticipant } from "../../types/meetups/meetup-session.js";
import { ConflictError } from "../../utils/errors.js";
import { legacyOptimization, type MeetupPreferences } from "../../types/meetups/meetup-preferences.js";
import { ResolveStandaloneParticipantsUseCase } from "./resolve-standalone-participants.usecase.js";

const configuredManualLimit = Number(process.env.MEETUP_MANUAL_PARTICIPANT_LIMIT);
export const manualParticipantLimit = Number.isInteger(configuredManualLimit) &&
  configuredManualLimit >= 1 && configuredManualLimit <= 30 ? configuredManualLimit : 12;

function sessionView(session: MeetupSession, uid: string, preferences: MeetupPreferences, readiness: MeetupReadinessSummary | null,
  standalone: StandaloneParticipant[] = []) {
  return {
    id: session.id, session_type: session.session_type, group_id: session.group_id, outing_id: session.outing_id,
    status: session.status, calculation_status: session.calculation_status, input_version: session.input_version,
    expires_at: session.expires_at, optimization: session.optimization, preferences,
    can_manage: session.status === "ACTIVE" && session.created_by_user_id === uid, readiness,
    ...(session.session_type === "STANDALONE" && {
      standalone_participants: standalone, manual_participant_limit: manualParticipantLimit,
    }),
  };
}

export class MeetupSessionWorkflow {
  constructor(
    readonly repository = new MeetupSessionRepository(),
    readonly policy = new MeetupSessionAuthorizationPolicy(),
    private readonly participants = new MeetupParticipantResolver(),
    private readonly versions = new MeetupInputVersionService(),
    private readonly coordinator: MeetupCalculationCoordinator = routingUnavailable,
    readonly standalone = new StandaloneMeetupRepository(),
    readonly standalonePolicy = new StandaloneMeetupAuthorizationPolicy(),
    private readonly standaloneResolver = new ResolveStandaloneParticipantsUseCase(standalone),
    readonly preferences = new MeetupPreferencesRepository(),
  ) {}

  async resolve(tx: Prisma.TransactionClient, session: MeetupSession, uid: string, currentPreferences?: MeetupPreferences) {
    const preferences = currentPreferences ?? await this.preferences.get(tx, session);
    if (session.status !== "ACTIVE") return sessionView(session, uid, preferences, null);
    const standalone = session.session_type === "STANDALONE"
      ? await this.standaloneResolver.execute(tx, session) : null;
    const { readiness, inputs } = standalone ?? await this.participants.resolve(tx, session, uid);
    const digest = this.versions.digest(session.id, preferences, inputs);
    const changed = digest !== session.input_digest;
    const version = session.input_version + Number(changed && session.input_digest !== null);
    const { intended, usable } = readiness;
    const calculation = await this.coordinator.prepare(tx, session.id, version, { intended, usable }, preferences);
    if (changed || calculation !== session.calculation_status) {
      session = await tx.meetup_sessions.update({ where: { id: session.id },
        data: { input_digest: digest, input_version: version, calculation_status: calculation,
          optimization: legacyOptimization(preferences.travelFairnessMode) } });
    }
    return sessionView(session, uid, preferences, readiness, standalone?.participants);
  }

  async withSession<T>(uid: string, id: string, run: (tx: Prisma.TransactionClient, session: MeetupSession) => Promise<T>,
    options: { standaloneOnly?: boolean; activeOnly?: boolean; managerOnly?: boolean } = {}) {
    const outcome = await this.repository.transaction(async tx => {
      let session = await this.repository.get(tx, id);
      if (options.standaloneOnly || session.session_type === "STANDALONE") {
        this.standalonePolicy.requireOwner(session, uid);
      } else {
        await this.policy.requireMember(tx, session.group_id!, uid);
      }
      if (options.managerOnly) this.policy.requireManager(session, uid);
      if (session.status === "ACTIVE" && session.expires_at <= new Date()) {
        session = await this.close(tx, session, "EXPIRED");
      }
      if (options.activeOnly && session.status !== "ACTIVE") return { closed: true } as const;
      return { closed: false, result: await run(tx, session) } as const;
    });
    if (outcome.closed) throw new ConflictError("Meetup is closed");
    return outcome.result;
  }

  async close(tx: Prisma.TransactionClient, session: MeetupSession, status: "CANCELLED" | "EXPIRED") {
    const standalone = session.session_type === "STANDALONE";
    const closed = await tx.meetup_sessions.update({ where: { id: session.id },
      data: { status, ...(standalone && { input_digest: null }) },
    });
    if (standalone) await this.standalone.clear(tx, session.id);
    return closed;
  }
}

export class InitializeGroupMeetupUseCase {
  constructor(private readonly flow: MeetupSessionWorkflow) {}
  execute(uid: string, groupId: string, outingId: string | null) {
    return this.flow.repository.transaction(async tx => {
      await this.flow.policy.requireMember(tx, groupId, uid);
      const session = await this.flow.repository.initialize(tx, groupId, outingId, uid);
      return this.flow.resolve(tx, session, uid);
    });
  }
}

export class GetMeetupSessionUseCase {
  constructor(private readonly flow: MeetupSessionWorkflow) {}
  execute(uid: string, id: string) {
    return this.flow.withSession(uid, id, (tx, session) => this.flow.resolve(tx, session, uid));
  }
}

export class GetMeetupReadinessUseCase {
  constructor(private readonly get: GetMeetupSessionUseCase) {}
  async execute(uid: string, id: string) {
    const { readiness } = await this.get.execute(uid, id);
    if (!readiness) throw new ConflictError("Meetup is closed");
    return readiness;
  }
}

export class CancelMeetupSessionUseCase {
  constructor(private readonly flow: MeetupSessionWorkflow) {}
  execute(uid: string, id: string) {
    return this.flow.withSession(uid, id, async (tx, session) => {
      if (session.status === "ACTIVE") {
        session = await this.flow.close(tx, session, "CANCELLED");
      }
      return this.flow.resolve(tx, session, uid);
    }, { managerOnly: true });
  }
}
