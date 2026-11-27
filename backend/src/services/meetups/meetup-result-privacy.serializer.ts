import { ratingStatistics } from "../../repositories/places/place-rating-statistics.repository.js";
import type { MeetupRecommendationRepository } from "../../repositories/meetups/meetup-recommendation.repository.js";
import type { MeetupCandidate } from "./meetup-candidate-filter.service.js";
import { catalogExplanationCodes, type MeetupCalculation, type MeetupResult,
  type PublicMeetupRecommendation } from "../../types/meetups/meetup-result.js";

type RankedPlace = Awaited<ReturnType<MeetupRecommendationRepository["list"]>>[number];

export class MeetupResultPrivacySerializer {
  calculation(record: MeetupCalculation, status: MeetupResult["status"]): NonNullable<MeetupResult["calculation"]> {
    return {
      id: record.id, inputVersion: record.input_version, attempt: record.attempt,
      optimizationPolicyVersion: record.optimization_policy_version,
      calculatedAt: record.calculated_at, expiresAt: record.expires_at,
      safeFailureCode: status === "FAILED" ? "CALCULATION_FAILED" : null,
    };
  }

  recommendation(row: RankedPlace, eligible: MeetupCandidate): PublicMeetupRecommendation {
    const { recommendation, place, rating } = row;
    const { averageRating, ratingCount } = ratingStatistics(rating);
    // Explicit allowlist. Even coarse releases can be compared across changing rosters.
    return {
      placeId: recommendation.place_id, place, rank: recommendation.rank, averageRating, ratingCount,
      budgetLevel: eligible.budgetLevel,
      explanationCodes: catalogExplanationCodes.filter(code => recommendation.explanation_codes.includes(code)),
    };
  }
}
