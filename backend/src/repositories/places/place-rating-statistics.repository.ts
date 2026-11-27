import type { Prisma, place_rating_statistics } from "@prisma/client";
import { prisma } from "../../config/database.js";
import { NotFoundError } from "../../utils/errors.js";
import type { PlaceRatingStatistics } from "../../types/places/place-review.types.js";

export function ratingStatistics(
  row?: (Omit<place_rating_statistics, "updated_at"> & { updated_at: Date | string }) | null,
): PlaceRatingStatistics {
  return {
    averageRating: row?.rating_count ? row.rating_sum / row.rating_count : null,
    ratingCount: row?.rating_count ?? 0,
    updatedAt: row ? new Date(row.updated_at) : null,
    writtenReviewCount: row?.written_review_count ?? 0,
    distribution: {
      1: row?.one_star_count ?? 0,
      2: row?.two_star_count ?? 0,
      3: row?.three_star_count ?? 0,
      4: row?.four_star_count ?? 0,
      5: row?.five_star_count ?? 0,
    },
  };
}

export class PlaceRatingStatisticsRepository {
  async get(placeId: string, client: Prisma.TransactionClient = prisma) {
    const row = await client.places.findUnique({
      where: { id: placeId },
      select: { rating_statistics: true },
    });
    if (!row) throw new NotFoundError("Place");
    return ratingStatistics(row.rating_statistics);
  }

  async attach<T>(rows: T[], placeId: (row: T) => string | null | undefined,
    client: Prisma.TransactionClient = prisma) {
    const ids = [...new Set(rows.map(placeId).filter((id): id is string => !!id))];
    const statistics = ids.length ? await client.place_rating_statistics.findMany({
      where: { place_id: { in: ids } },
    }) : [];
    const byId = new Map(statistics.map((row) => [row.place_id, row]));
    return rows.map((row) => {
      const id = placeId(row);
      return { ...row, ...(id && { rating_statistics: ratingStatistics(byId.get(id)) }) };
    });
  }
}
