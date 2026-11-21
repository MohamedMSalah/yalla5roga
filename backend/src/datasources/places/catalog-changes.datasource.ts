import { Prisma } from "@prisma/client";
import { prisma } from "../../config/database.js";
import { encodeChangeCursor, type ChangeCursor } from "../../services/places/catalog-cursor.js";
import { publicPlace } from "../../services/places/public-place.js";

export async function readCatalogChanges(cursor: ChangeCursor, limit: number) {
  return prisma.$transaction(async (tx) => {
    const [snapshot] = await tx.$queryRaw<{ watermark: string }[]>
      `SELECT pg_snapshot_xmin(pg_current_snapshot())::text AS watermark`;
    const watermark = snapshot!.watermark;
    const revisions = await tx.$queryRaw<ChangeCursor[]>`
      SELECT c.revision::text AS revision, c.kind, c.entity_id AS id
      FROM place_catalog_changes c
      WHERE (c.revision, c.kind, c.entity_id) > (${cursor.revision}::xid8, ${cursor.kind}, ${cursor.id})
        AND c.revision < ${watermark}::xid8
      ORDER BY c.revision, c.kind, c.entity_id LIMIT ${limit + 1}`;
    const changes = revisions.slice(0, limit);
    const ids = (kind: string) => changes.filter(row => row.kind === kind).map(row => row.id);
    const placeIds = ids("place");
    const brandIds = ids("brand");
    const categoryIds = ids("category");
    const vibeIds = ids("vibe");
    const places = placeIds.length ? await tx.places.findMany({
      where: { id: { in: placeIds }, is_active: true, status: "active" },
      select: {
        id: true, name: true, name_ar: true, name_en: true, area: true, address: true,
        vibe: true, description: true, price_level: true, price_min: true, price_max: true,
        currency: true, cover_image_url: true, latitude: true, longitude: true, featured: true,
        is_active: true, status: true, category_id: true, brand_id: true, branch_name: true,
        source: true, source_type: true, source_id: true, phone: true, website: true,
        opening_hours: true, city: true, district: true, updated_at: true,
        place_images: {
          orderBy: [{ sort_order: "asc" }, { id: "asc" }],
          select: { image_url: true, caption: true },
        },
        place_hours: { select: { day: true, opens_at: true, closes_at: true, is_closed: true } },
        place_prices: { select: { label: true, amount: true, currency: true } },
        place_vibes: { select: { vibe_id: true } },
      },
    }) : [];
    const brands = brandIds.length ? await tx.place_brands.findMany({
      where: { id: { in: brandIds } },
      select: { id: true, name: true },
    }) : [];
    const categories = categoryIds.length ? await tx.place_categories.findMany({
      where: { id: { in: categoryIds }, is_active: true },
    }) : [];
    const vibes = vibeIds.length ? await tx.vibes.findMany({
      where: { id: { in: vibeIds }, is_active: true },
    }) : [];
    const records = new Map<string, unknown>([
      ...places.map(p => [`place:${p.id}`, publicPlace(p)] as const),
      ...brands.map(p => [`brand:${p.id}`, p] as const),
      ...categories.map(p => [`category:${p.id}`, p] as const),
      ...vibes.map(p => [`vibe:${p.id}`, p] as const),
    ]);
    const hasMore = revisions.length > limit;
    const checkpoint = BigInt(watermark) > BigInt(cursor.revision)
      ? { revision: watermark, kind: "", id: "" } : cursor;
    return {
      changes: changes.map(({ kind, id }) => ({ kind, id, record: records.get(`${kind}:${id}`) ?? null })),
      cursor: encodeChangeCursor(hasMore ? changes.at(-1)! : checkpoint),
      has_more: hasMore,
    };
  }, { isolationLevel: Prisma.TransactionIsolationLevel.RepeatableRead });
}
