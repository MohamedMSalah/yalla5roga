import { Prisma } from "@prisma/client";

export class BayesianRatingService {
  static configuredPriorWeight(raw = process.env.PLACE_RATING_PRIOR_WEIGHT): number {
    const value = raw?.trim();
    if (!value) return 20;
    if (!/^\d+$/.test(value)) throw new Error("PLACE_RATING_PRIOR_WEIGHT must be a positive safe integer");
    return BayesianRatingService.validateWeight(Number(value));
  }

  private static validateWeight(weight: number) {
    if (!Number.isSafeInteger(weight) || weight < 1) {
      throw new Error("PLACE_RATING_PRIOR_WEIGHT must be a positive safe integer");
    }
    return weight;
  }

  readonly priorWeight: number;

  constructor(priorWeight = BayesianRatingService.configuredPriorWeight()) {
    this.priorWeight = BayesianRatingService.validateWeight(priorWeight);
  }

  score(placeSum: number, placeCount: number, globalMean: number) {
    return (placeSum + this.priorWeight * globalMean) / (placeCount + this.priorWeight);
  }

  /** Prompt 08 already applied review eligibility when producing these counters. */
  globalStatisticsSql() {
    return Prisma.sql`
      SELECT coalesce(sum(rating_sum), 0) AS rating_sum,
        coalesce(sum(rating_count), 0) AS rating_count,
        concat(${this.priorWeight}::bigint, ':', coalesce(sum(rating_sum), 0), ':',
          coalesce(sum(rating_count), 0), ':',
          coalesce(sum(hashtextextended(concat(place_id, ':', rating_sum, ':', rating_count), 0)), 0)) AS version
      FROM place_rating_statistics
      WHERE rating_count > 0`;
  }

  /**
   * (place sum + m × (global sum / global count)) / (place count + m).
   * Combine into one numeric division with ample scale for ordering and cursors.
   */
  scoreSql(placeSum: Prisma.Sql, placeCount: Prisma.Sql, globalSum: Prisma.Sql, globalCount: Prisma.Sql) {
    const weight = Prisma.sql`${this.priorWeight}::numeric`;
    return Prisma.sql`
      ((${placeSum}::numeric * ${globalCount} + ${weight} * ${globalSum})::numeric(100, 50))
      / ((nullif(${placeCount}, 0) + ${weight}) * nullif(${globalCount}, 0))`;
  }
}
