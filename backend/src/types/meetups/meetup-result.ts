import type { meetup_calculations, meetup_calculation_status, meetup_recommendations, meetup_session_status, places } from "@prisma/client";
import type { BudgetLevel, MeetupPreferences } from "./meetup-preferences.js";

export type MeetupCalculation = meetup_calculations;
export type MeetupRecommendation = meetup_recommendations;
export const meetupOptimizationPolicyVersion = "1";
export const meetupRecommendationLimit = 5;

export const catalogExplanationCodes = [
  "MATCHES_CATEGORY", "MATCHES_BUDGET", "MEETS_MINIMUM_RATING", "OPEN_AT_MEETUP_TIME",
] as const;

type MeetupPlaceSummary = Pick<places, "id" | "name" | "name_ar" | "name_en" | "area" | "address" |
  "vibe" | "category_id" | "status" | "latitude" | "longitude" | "price_level" | "cover_image_url" |
  "source" | "branch_name" | "brand_id"> & {
  branch_id: string;
  brand_name: string | null;
  branch_count: number;
  vibes: string[];
};

export interface PublicMeetupRecommendation {
  placeId: string;
  place: MeetupPlaceSummary;
  rank: number;
  averageRating: number | null;
  ratingCount: number;
  budgetLevel: BudgetLevel;
  explanationCodes: (typeof catalogExplanationCodes)[number][];
  // Reserved for a future explicit release policy.
  travelStatistics?: { averageDurationMinutes: number };
  matchScore?: number;
}

export type MeetupResult = {
  status: meetup_calculation_status;
  sessionStatus: meetup_session_status;
  inputVersion: number;
  intendedParticipantCount: number;
  includedParticipantCount: number;
  unavailableParticipantCount: number;
  isPartial: boolean;
  preferences: MeetupPreferences;
  calculation: {
    id: string;
    inputVersion: number;
    attempt: number;
    optimizationPolicyVersion: string;
    calculatedAt: Date | null;
    expiresAt: Date | null;
    safeFailureCode: string | null;
  } | null;
  recommendations: readonly PublicMeetupRecommendation[];
};
