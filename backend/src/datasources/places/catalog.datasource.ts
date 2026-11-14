import { Prisma } from "@prisma/client";
import { prisma } from "../../config/database.js";
import type { CatalogQuery } from "../../validators/places/catalog.validator.js";
import { nearbySearchBounds } from "../../services/places/nearby-search-bounds.js";

/** All predicates run in PostgreSQL; JSON relations are aggregated only for the page. */
export class CatalogDatasource {
  syncHistory(limit: number, offset: number) {
    return prisma.place_sync_runs.findMany({
      take: limit,
      skip: offset,
      orderBy: { started_at: "desc" },
    });
  }
  async list(q: CatalogQuery) {
    const conditions: Prisma.Sql[] = [
      Prisma.sql`p.is_active=true`,
      Prisma.sql`p.status=${q.status}`,
    ];
    if (q.featured === "true") conditions.push(Prisma.sql`p.featured=true`);
    if (q.vibe) conditions.push(Prisma.sql`p.vibe::text=${q.vibe}`);
    if (q.categories.length)
      conditions.push(
        Prisma.sql`p.category_id IN (${Prisma.join(q.categories)})`,
      );
    // OR within each dimension; AND between categories, vibes, search and distance.
    if (q.vibes.length)
      conditions.push(
        Prisma.sql`EXISTS(SELECT 1 FROM place_vibes pv JOIN vibes v ON v.id=pv.vibe_id WHERE pv.place_id=p.id AND v.is_active=true AND pv.vibe_id IN (${Prisma.join(q.vibes)}))`,
      );
    if (q.search) {
      const term = `%${q.search.replace(/[\\%_]/g, "\\$&")}%`;
      conditions.push(
        Prisma.sql`(p.name ILIKE ${term} OR p.name_ar ILIKE ${term} OR p.name_en ILIKE ${term} OR p.area ILIKE ${term} OR p.address ILIKE ${term})`,
      );
    }
    if (q.bbox)
      conditions.push(
        Prisma.sql`p.longitude BETWEEN ${q.bbox[0]}::float8 AND ${q.bbox[2]}::float8 AND p.latitude BETWEEN ${q.bbox[1]}::float8 AND ${q.bbox[3]}::float8`,
      );
    let distance = Prisma.sql`NULL::float8`;
    if (q.lat !== undefined && q.lng !== undefined) {
      distance = Prisma.sql`6371.0088*2*asin(least(1.0,sqrt(power(sin(radians(p.latitude-${q.lat}::float8)/2),2)+cos(radians(${q.lat}::float8))*cos(radians(p.latitude))*power(sin(radians(p.longitude-${q.lng}::float8)/2),2))))`;
      conditions.push(
        Prisma.sql`p.latitude IS NOT NULL AND p.longitude IS NOT NULL`,
      );
      if (q.radiusKm !== undefined) {
        const bounds = nearbySearchBounds(q.lat, q.lng, q.radiusKm);
        conditions.push(
          Prisma.sql`p.latitude BETWEEN ${bounds.latitude[0]}::float8 AND ${bounds.latitude[1]}::float8`,
        );
        if (bounds.longitudes.length)
          conditions.push(
            Prisma.sql`(${Prisma.join(
              bounds.longitudes.map(
                ([min, max]) =>
                  Prisma.sql`p.longitude BETWEEN ${min}::float8 AND ${max}::float8`,
              ),
              " OR ",
            )})`,
          );
        conditions.push(Prisma.sql`${distance}<=${q.radiusKm}::float8`);
      }
    }
    const where = Prisma.join(conditions, " AND ");
    const order =
      q.sort === "distance"
        ? Prisma.sql`distance_km ASC,p.id ASC`
        : q.sort === "name"
          ? Prisma.sql`p.name ASC,p.id ASC`
          : Prisma.sql`p.updated_at DESC,p.id ASC`;
    const rows = await prisma.$queryRaw<
      any[]
    >`SELECT p.*,p.cover_image_url AS image_url,${distance} AS distance_km,
      coalesce((SELECT jsonb_agg(pv.vibe_id ORDER BY pv.vibe_id) FROM place_vibes pv JOIN vibes v ON v.id=pv.vibe_id WHERE pv.place_id=p.id AND v.is_active),'[]'::jsonb) AS vibes,
      (SELECT to_jsonb(c) FROM place_categories c WHERE c.id=p.category_id) AS category
      FROM places p WHERE ${where} ORDER BY ${order} LIMIT ${q.limit + 1} OFFSET ${q.offset}`;
    const hasMore = rows.length > q.limit;
    return {
      places: rows.slice(0, q.limit),
      pagination: {
        limit: q.limit,
        offset: q.offset,
        has_more: hasMore,
        next_offset: hasMore ? q.offset + q.limit : null,
      },
    };
  }
  categories() {
    return prisma.place_categories.findMany({
      where: { is_active: true },
      orderBy: [{ sort_order: "asc" }, { id: "asc" }],
    });
  }
  vibes() {
    return prisma.vibes.findMany({
      where: { is_active: true },
      orderBy: [{ sort_order: "asc" }, { id: "asc" }],
    });
  }
  async version() {
    const [row] = await prisma.$queryRaw<
      { version: Date | null }[]
    >`SELECT greatest((SELECT max(updated_at) FROM places),(SELECT max(updated_at) FROM place_categories),(SELECT max(updated_at) FROM vibes)) AS version`;
    return row?.version?.toISOString() ?? "empty";
  }
}
