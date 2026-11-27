import type { Prisma } from "@prisma/client";
import { type BudgetLevel, type MeetupPreferences, OptimizationPriority } from "../../types/meetups/meetup-preferences.js";
import { BayesianRatingService } from "../places/bayesian-rating.service.js";
import { isOpenAt } from "./meetup-opening-hours.js";
import { ResolvePlaceBudgetLevelService, type ComparablePlacePrice } from "./resolve-place-budget-level.service.js";

const catalogFields = {
  id: true, category_id: true, price_level: true, currency: true, opening_hours: true,
  place_hours: { select: { day: true, opens_at: true, closes_at: true, is_closed: true, source: true } },
  place_prices: { select: { label: true, amount: true, currency: true, source: true, evidence: true } },
  rating_statistics: { select: { rating_sum: true, rating_count: true } },
} satisfies Prisma.placesSelect;
type CatalogPlace = Prisma.placesGetPayload<{ select: typeof catalogFields }>;

export interface MeetupCandidate {
  placeId: string;
  categoryId: string | null;
  budgetLevel: BudgetLevel;
  comparablePrice: ComparablePlacePrice | null;
  averageRating: number | null;
  bayesianRating: number | null;
}

export interface MeetupJourney {
  durationSeconds: number;
  distanceMeters: number | null;
}

export interface RoutedMeetupCandidate extends MeetupCandidate {
  journeys: readonly MeetupJourney[];
}

// Each array follows the same ordered participant roster for the input version.
export type MeetupRoutingEvidence =
  | { status: "UNAVAILABLE" }
  | { status: "AVAILABLE"; participantCount: number; journeysByPlace: ReadonlyMap<string, readonly MeetupJourney[]> };

export class MeetupCandidateFilterService {
  constructor(private readonly budgets = new ResolvePlaceBudgetLevelService(),
    private readonly ratings = new BayesianRatingService()) {}

  async findCatalogCandidates(tx: Prisma.TransactionClient, placeIds: readonly string[],
    preferences: MeetupPreferences, evaluatedAt: Date): Promise<MeetupCandidate[]> {
    if (!placeIds.length) return [];
    const places = await tx.places.findMany({
      where: {
        id: { in: [...placeIds] },
        status: "active",
        is_active: true,
        ...(preferences.categoryIds.length && {
          category_id: { in: preferences.categoryIds },
          category: { is_active: true },
        }),
      },
      select: catalogFields,
    });
    const global = preferences.additionalPriorities.includes(OptimizationPriority.TOP_RATED)
      ? (await tx.$queryRaw<{ rating_sum: bigint; rating_count: bigint }[]>(this.ratings.globalStatisticsSql()))[0]
      : undefined;
    const prior = global && Number(global.rating_count) > 0
      ? Number(global.rating_sum) / Number(global.rating_count) : null;
    const result: MeetupCandidate[] = [];
    for (const place of places) {
      const candidate = this.filterCatalogPlace(place, preferences, evaluatedAt, prior);
      if (candidate) result.push(candidate);
    }
    return result;
  }

  private filterCatalogPlace(place: CatalogPlace, preferences: MeetupPreferences,
    evaluatedAt: Date, prior: number | null): MeetupCandidate | null {
    const budgetLevel = this.budgets.resolve(place);
    const budgets: readonly BudgetLevel[] = preferences.budgetLevels;
    if (budgets.length && !budgets.includes(budgetLevel)) return null;

    const rating = place.rating_statistics;
    const average = rating && rating.rating_count > 0 ? rating.rating_sum / rating.rating_count : null;
    const minimum = preferences.minimumRating;
    if (minimum !== null && (!rating?.rating_count || rating.rating_sum < rating.rating_count * minimum)) return null;
    if (preferences.requireOpenAtMeetupTime && !isOpenAt(place, preferences.plannedMeetupAt ?? evaluatedAt)) return null;

    return {
      placeId: place.id,
      categoryId: place.category_id,
      budgetLevel,
      comparablePrice: this.budgets.comparablePrice(place),
      averageRating: average,
      bayesianRating: rating && rating.rating_count > 0 && prior !== null
        ? this.ratings.score(rating.rating_sum, rating.rating_count, prior) : null,
    };
  }

  applyTravelLimit(candidates: readonly MeetupCandidate[], preferences: MeetupPreferences,
    routing: MeetupRoutingEvidence): MeetupCandidate[] {
    const limit = preferences.maximumTravelDurationSeconds;
    if (routing.status === "UNAVAILABLE" || limit === null) return [...candidates];
    return this.attachTravel(candidates, routing, limit);
  }

  attachTravel(candidates: readonly MeetupCandidate[],
    routing: Extract<MeetupRoutingEvidence, { status: "AVAILABLE" }>,
    limit = Infinity): RoutedMeetupCandidate[] {
    if (routing.participantCount < 1) return [];
    return candidates.flatMap(candidate => {
      const journeys = routing.journeysByPlace.get(candidate.placeId);
      if (journeys?.length !== routing.participantCount || !journeys.every(journey =>
        Number.isFinite(journey.durationSeconds) && journey.durationSeconds >= 0 &&
        journey.durationSeconds <= limit)) return [];
      return [{ ...candidate, journeys }];
    });
  }
}
