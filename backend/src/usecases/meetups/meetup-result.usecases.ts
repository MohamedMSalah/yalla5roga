import type { Prisma } from "@prisma/client";
import { MeetupCalculationRepository } from "../../repositories/meetups/meetup-calculation.repository.js";
import { MeetupRecommendationRepository } from "../../repositories/meetups/meetup-recommendation.repository.js";
import { MeetupCandidateFilterService, type MeetupRoutingEvidence } from "../../services/meetups/meetup-candidate-filter.service.js";
import { MeetupCandidateRankingService } from "../../services/meetups/meetup-candidate-ranking.service.js";
import { MeetupInvalidationService } from "../../services/meetups/meetup-invalidation.service.js";
import { MeetupResultPrivacySerializer } from "../../services/meetups/meetup-result-privacy.serializer.js";
import { meetupRecommendationLimit, type MeetupCalculation, type MeetupResult } from "../../types/meetups/meetup-result.js";
import type { MeetupSession } from "../../types/meetups/meetup-session.js";
import { ConflictError, NotFoundError } from "../../utils/errors.js";
import type { MeetupSessionWorkflow } from "./meetup-session.usecases.js";

export class ValidateMeetupResultVersionUseCase {
  constructor(private readonly invalidation = new MeetupInvalidationService()) {}

  async execute(tx: Prisma.TransactionClient, calculation: MeetupCalculation,
    session: { id: string; status: string; input_version: number; expires_at: Date }, fingerprint: string | null) {
    const current = this.invalidation.isCurrent(calculation, session, fingerprint);
    if (!current) await this.invalidation.invalidate(tx, calculation);
    return current;
  }
}

const published = (status: MeetupCalculation["calculation_status"]) =>
  status === "READY" || status === "PARTIAL";

export class GetMeetupResultsUseCase {
  constructor(readonly flow: MeetupSessionWorkflow,
    readonly calculations = new MeetupCalculationRepository(),
    private readonly recommendations = new MeetupRecommendationRepository(),
    private readonly filters = new MeetupCandidateFilterService(),
    readonly versions = new ValidateMeetupResultVersionUseCase(),
    private readonly invalidation = new MeetupInvalidationService(),
    private readonly serializer = new MeetupResultPrivacySerializer()) {}

  execute(uid: string, sessionId: string, calculationId?: string) {
    return this.flow.withSession(uid, sessionId,
      (tx, session) => this.read(tx, session, uid, { calculationId }));
  }

  async read(tx: Prisma.TransactionClient, session: MeetupSession, uid: string,
    options: { calculationId?: string; refresh?: boolean; lockCatalog?: boolean }): Promise<MeetupResult> {
    const resolved = await this.flow.resolve(tx, session, uid);
    const { input_digest: fingerprint } = await tx.meetup_sessions.findUniqueOrThrow({
      where: { id: session.id }, select: { input_digest: true },
    });
    const { readiness, preferences } = resolved;
    const intended = readiness?.intended ?? 0;
    const included = readiness?.usable ?? 0;
    let record = options.calculationId
      ? await this.calculations.get(tx, session.id, options.calculationId)
      : await this.calculations.latest(tx, session.id);
    if (options.calculationId && !record) throw new NotFoundError("Meetup calculation");

    let current = record !== null && await this.versions.execute(tx, record, resolved, fingerprint);
    let recommendations: Awaited<ReturnType<MeetupRecommendationRepository["list"]>> = [];
    let eligible: Awaited<ReturnType<MeetupCandidateFilterService["findCatalogCandidates"]>> = [];
    if (record && current && published(record.calculation_status)) {
      recommendations = await this.recommendations.list(tx, record.id);
      const placeIds = recommendations.map(row => row.recommendation.place_id);
      if (options.lockCatalog) await this.recommendations.lockCatalogPlaces(tx, placeIds);
      eligible = await this.filters.findCatalogCandidates(tx, placeIds, preferences, new Date());
      if (!recommendations.length || eligible.length !== recommendations.length ||
          recommendations.some((row, index) => row.recommendation.rank !== index + 1)) {
        await this.invalidation.invalidate(tx, record);
        current = false;
      }
    }

    const deferred = included === 0 ? "INSUFFICIENT_DATA" : "ROUTING_UNAVAILABLE";
    if (options.refresh && readiness && fingerprint && (!current || record?.calculation_status === "FAILED")) {
      if (record) await this.invalidation.invalidate(tx, record);
      const attempt = record?.input_version === resolved.input_version ? record.attempt + 1 : 1;
      record = await this.calculations.create(tx, session.id, resolved.input_version,
        fingerprint, attempt, readiness, session.expires_at);
      current = true;
    }
    const status = !readiness || (record && !current) ? "STALE" : record?.calculation_status ?? deferred;
    return {
      status, sessionStatus: resolved.status, inputVersion: resolved.input_version, preferences,
      intendedParticipantCount: intended, includedParticipantCount: included,
      unavailableParticipantCount: intended - included, isPartial: included > 0 && included < intended,
      calculation: record ? this.serializer.calculation(record, status) : null,
      recommendations: published(status) ? recommendations.map(row =>
        this.serializer.recommendation(row, eligible.find(place => place.placeId === row.recommendation.place_id)!)) : [],
    };
  }
}

export class RefreshMeetupResultsUseCase {
  constructor(private readonly results: GetMeetupResultsUseCase) {}

  execute(uid: string, sessionId: string) {
    return this.results.flow.withSession(uid, sessionId,
      (tx, session) => this.results.read(tx, session, uid, { refresh: true }), { activeOnly: true });
  }
}

export interface PublishMeetupResultInput {
  sessionId: string;
  calculationId: string;
  // A future trusted routing worker must evaluate the selected input version as a complete cohort.
  routing: Extract<MeetupRoutingEvidence, { status: "AVAILABLE" }>;
}

export interface PublishMeetupResultsUseCase {
  execute(input: PublishMeetupResultInput): Promise<boolean>;
}

/** Internal handoff for a future routing coordinator. No HTTP route creates or publishes routed evidence. */
export class PublishRoutedMeetupResultsUseCase implements PublishMeetupResultsUseCase {
  constructor(private readonly flow: MeetupSessionWorkflow,
    private readonly calculations = new MeetupCalculationRepository(),
    private readonly recommendations = new MeetupRecommendationRepository(),
    private readonly versions = new ValidateMeetupResultVersionUseCase(),
    private readonly filters = new MeetupCandidateFilterService(),
    private readonly ranking = new MeetupCandidateRankingService()) {}

  async execute({ sessionId, calculationId, routing }: PublishMeetupResultInput) {
    return this.flow.repository.transaction(async tx => {
      const session = await this.flow.repository.get(tx, sessionId);
      const resolved = await this.flow.resolve(tx, session, session.created_by_user_id);
      const { input_digest: fingerprint } = await tx.meetup_sessions.findUniqueOrThrow({
        where: { id: sessionId }, select: { input_digest: true },
      });
      const record = await this.calculations.latest(tx, sessionId);
      if (!record || record.id !== calculationId || !await this.versions.execute(tx, record, resolved, fingerprint)) {
        return false;
      }
      if (!["QUEUED", "CALCULATING"].includes(record.calculation_status)) {
        return published(record.calculation_status) || record.calculation_status === "NO_MATCHING_VENUES";
      }
      if (routing.status !== "AVAILABLE" || routing.participantCount < 1 ||
          routing.participantCount !== record.included_participant_count ||
          routing.participantCount !== resolved.readiness?.usable) {
        throw new ConflictError("Routing evidence does not match the current cohort");
      }
      const catalogIds = [...routing.journeysByPlace.keys()];
      await this.recommendations.lockCatalogPlaces(tx, catalogIds);
      const now = new Date();
      const candidates = await this.filters.findCatalogCandidates(tx, catalogIds, resolved.preferences, now);
      const ranked = this.ranking.rank(candidates, resolved.preferences, routing).slice(0, meetupRecommendationLimit);
      const expiresAt = new Date(Math.min(record.expires_at!.getTime(), session.expires_at.getTime(),
        now.getTime() + 30 * 60 * 1000));
      if (expiresAt <= new Date()) return false;
      if (ranked.length) {
        const preferences = resolved.preferences;
        await this.recommendations.create(tx, ranked.map((candidate, index) => {
          const durations = candidate.journeys.map(journey => Math.round(journey.durationSeconds));
          const total = durations.reduce((sum, seconds) => sum + seconds, 0);
          const maximum = Math.max(...durations);
          const minimum = Math.min(...durations);
          const meters = candidate.journeys.map(journey => journey.distanceMeters);
          return {
            calculation_id: record.id, place_id: candidate.placeId, rank: index + 1,
            average_duration_seconds: total / durations.length, maximum_duration_seconds: maximum,
            total_duration_seconds: total, minimum_duration_seconds: minimum,
            duration_spread_seconds: maximum - minimum,
            total_distance_meters: meters.every(value => value !== null && Number.isFinite(value) && value >= 0)
              ? meters.reduce<number>((sum, value) => sum + (value ?? 0), 0) : null,
            explanation_codes: [
              ...(preferences.categoryIds.length ? ["MATCHES_CATEGORY"] : []),
              ...(preferences.budgetLevels.length ? ["MATCHES_BUDGET"] : []),
              ...(preferences.minimumRating !== null ? ["MEETS_MINIMUM_RATING"] : []),
              ...(preferences.requireOpenAtMeetupTime ? ["OPEN_AT_MEETUP_TIME"] : []),
            ],
          };
        }));
      }
      await tx.meetup_calculations.update({
        where: { id: record.id }, data: {
          calculation_status: !ranked.length ? "NO_MATCHING_VENUES" : record.is_partial ? "PARTIAL" : "READY",
          candidate_place_ids: catalogIds,
          calculated_at: now, expires_at: expiresAt, safe_failure_code: null,
        },
      });
      return true;
    });
  }
}
