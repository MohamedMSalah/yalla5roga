import type { place_review_report_reason, place_review_visibility } from "@prisma/client";

export interface PlaceReview {
  id: string;
  placeId: string;
  rating: number;
  reviewText: string | null;
  createdAt: Date;
  updatedAt: Date;
  isMine: boolean;
  reviewer: { name: string };
  moderationStatus?: place_review_visibility;
}

export interface PlaceRatingStatistics {
  averageRating: number | null;
  ratingCount: number;
  updatedAt: Date | null;
  writtenReviewCount: number;
  distribution: Record<1 | 2 | 3 | 4 | 5, number>;
}

export type PlaceRatingInput = { rating: number; reviewText: string | null };
export type ReviewPageKey = { createdAt: Date; id: string };
export type ReportReason = place_review_report_reason;
