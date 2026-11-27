import { Prisma } from "@prisma/client";
import { publicPlace } from "../../services/places/public-place.js";

const cardFields = {
  id: true, name: true, name_ar: true, name_en: true, area: true, address: true, vibe: true,
  category_id: true, status: true, latitude: true, longitude: true, price_level: true,
  cover_image_url: true, source: true, branch_name: true,
  brand_id: true, place_images: { orderBy: [{ sort_order: "asc" }, { id: "asc" }], take: 1, select: { image_url: true } },
  brand: { select: { name: true, _count: { select: { branches: { where: { status: "active", is_active: true } } } } } },
  place_vibes: { where: { vibe: { is_active: true } }, select: { vibe_id: true } },
  rating_statistics: true,
} satisfies Prisma.placesSelect;

export class MeetupRecommendationRepository {
  async list(tx: Prisma.TransactionClient, calculationId: string) {
    const rows = await tx.meetup_recommendations.findMany({
      where: { calculation_id: calculationId }, orderBy: { rank: "asc" },
      include: { place: { select: cardFields } },
    });
    return rows.map(({ place, ...recommendation }) => {
      const { rating_statistics: rating, ...placeFields } = place;
      const { external_source, external_place_id, place_images: _images, place_vibes: _vibes, ...summary } =
        publicPlace(placeFields);
      return { recommendation, place: summary, rating };
    });
  }

  async lockCatalogPlaces(tx: Prisma.TransactionClient, ids: readonly string[]) {
    if (!ids.length) return;
    await tx.$queryRaw`SELECT id FROM places WHERE id IN (${Prisma.join(ids.map(id => Prisma.sql`${id}::uuid`))})
      ORDER BY id FOR SHARE`;
  }

  create(tx: Prisma.TransactionClient, rows: Prisma.meetup_recommendationsCreateManyInput[]) {
    return tx.meetup_recommendations.createMany({ data: rows });
  }
}
