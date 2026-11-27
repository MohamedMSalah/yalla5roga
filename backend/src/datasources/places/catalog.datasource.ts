import { Prisma } from "@prisma/client";
import { prisma } from "../../config/database.js";
import type { CatalogQuery } from "../../validators/places/catalog.validator.js";
import { nearbySearchBounds } from "../../services/places/nearby-search-bounds.js";
import { decodeCatalogCursor, encodeCatalogCursor } from "../../services/places/catalog-cursor.js";
import { BayesianRatingService } from "../../services/places/bayesian-rating.service.js";
import { ConflictError } from "../../utils/errors.js";

const recommendationFields = Prisma.sql`p.id,p.name,p.name_ar,p.name_en,p.area,p.vibe,
  coalesce(nullif(p.cover_image_url,''), (
    SELECT i.image_url FROM place_images i
    WHERE i.place_id=p.id ORDER BY i.sort_order,i.id LIMIT 1
  ),'') AS cover_image_url`;

/** All predicates run in PostgreSQL; JSON relations are aggregated only for the page. */
export class CatalogDatasource {
  recommendations(limit: number) {
    const pivot = crypto.randomUUID();
    return prisma.$queryRaw<Array<Record<string, unknown>>>`
      WITH head AS MATERIALIZED (
        SELECT id, name, name_ar, name_en, area, vibe, cover_image_url
        FROM places WHERE is_active AND status='active' AND id >= ${pivot}::uuid
        ORDER BY id LIMIT ${limit}
      ), sample AS (
        SELECT * FROM head
        UNION ALL
        (SELECT id, name, name_ar, name_en, area, vibe, cover_image_url
         FROM places WHERE is_active AND status='active' AND id < ${pivot}::uuid
         ORDER BY id LIMIT (${limit}::int - (SELECT count(*)::int FROM head)))
      )
      SELECT ${recommendationFields} FROM sample p ORDER BY (p.id < ${pivot}::uuid),p.id`;
  }

  nearbyRecommendations(limit: number, lat: number, lng: number) {
    const bounds = nearbySearchBounds(lat, lng, 5);
    const longitude = bounds.longitudes.length
      ? Prisma.sql`AND (${Prisma.join(bounds.longitudes.map(([west, east]) =>
          Prisma.sql`longitude BETWEEN ${west}::float8 AND ${east}::float8`), " OR ")})`
      : Prisma.empty;
    return prisma.$queryRaw<Array<Record<string, unknown>>>`
      WITH candidates AS MATERIALIZED (
        SELECT id,name,name_ar,name_en,area,vibe,cover_image_url FROM places
        WHERE is_active AND status='active'
          AND latitude BETWEEN ${bounds.latitude[0]}::float8 AND ${bounds.latitude[1]}::float8
          ${longitude}
          AND longitude IS NOT NULL
          AND sin(radians(latitude-${lat}::float8)/2)^2 +
            cos(radians(${lat}::float8))*cos(radians(latitude)) *
            sin(radians(longitude-${lng}::float8)/2)^2 <= sin(5.0/12742)^2
        LIMIT 96
      ), sample AS MATERIALIZED (
        SELECT candidates.*,random() AS sample_order FROM candidates
        ORDER BY sample_order LIMIT ${limit}
      )
      SELECT ${recommendationFields} FROM sample p ORDER BY p.sample_order`;
  }

  syncHistory(limit: number, offset: number) {
    return prisma.place_sync_runs.findMany({
      take: limit,
      skip: offset,
      orderBy: { started_at: "desc" },
    });
  }
  brand(id: string) {
    return prisma.place_brands.findUnique({ where: { id }, include: {
      aliases: { select: { name: true } },
      _count: { select: { branches: { where: { is_active: true, status: "active" } } } },
    } });
  }
  async list(q: CatalogQuery, markers = false) {
    const conditions: Prisma.Sql[] = [
      Prisma.sql`p.is_active=true`,
      Prisma.sql`p.status=${q.status}`,
    ];
    if (q.brand_id) conditions.push(Prisma.sql`p.brand_id=${q.brand_id}::uuid`);
    if (q.featured === "true") conditions.push(Prisma.sql`p.featured=true`);
    if (q.vibe) conditions.push(Prisma.sql`p.vibe=${q.vibe}::outing_vibe`);
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
    if (q.bbox) {
      const [west, south, east, north] = q.bbox;
      const longitude = west! < east!
        ? Prisma.sql`p.longitude BETWEEN ${west}::float8 AND ${east}::float8`
        : Prisma.sql`(p.longitude >= ${west}::float8 OR p.longitude <= ${east}::float8)`;
      conditions.push(
        Prisma.sql`${longitude} AND p.latitude BETWEEN ${south}::float8 AND ${north}::float8`,
      );
    }
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
    const bayesian = q.sort === "top_rated" ? new BayesianRatingService() : null;
    const filterRatings = q.minRating !== undefined || !q.includeUnrated;
    const ratingJoin = bayesian || filterRatings
      ? Prisma.sql`LEFT JOIN place_rating_statistics r ON r.place_id=p.id` : Prisma.empty;
    const rankingJoin = bayesian ? Prisma.sql`
      CROSS JOIN rating_prior g
      CROSS JOIN LATERAL (SELECT coalesce(${bayesian.scoreSql(
        Prisma.sql`r.rating_sum`, Prisma.sql`r.rating_count`,
        Prisma.sql`g.rating_sum`, Prisma.sql`g.rating_count`,
      )}, 0) AS score, coalesce(r.rating_count, 0) AS count) ranking`
      : Prisma.empty;
    if (filterRatings) conditions.push(Prisma.sql`r.rating_count > 0`);
    if (q.minRating !== undefined) {
      conditions.push(Prisma.sql`r.rating_sum >= r.rating_count * ${q.minRating.toString()}::numeric`);
    }
    const cursor = decodeCatalogCursor(q);
    if (cursor) {
      if (cursor.rating) {
        conditions.push(Prisma.sql`g.version = ${cursor.rating.version}
          AND (-ranking.score, -ranking.count, p.id) >
            (-${cursor.value}::numeric, -${cursor.rating.count}::int, ${cursor.id}::uuid)`);
      } else if (q.sort === "id") conditions.push(Prisma.sql`p.id > ${cursor.id}::uuid`);
      else if (q.sort === "updated") conditions.push(Prisma.sql`p.updated_at <= ${cursor.value}::timestamptz AND (p.updated_at < ${cursor.value}::timestamptz OR p.id > ${cursor.id}::uuid)`);
      else if (q.sort === "name") conditions.push(Prisma.sql`(p.name > ${cursor.value} OR (p.name = ${cursor.value} AND p.id > ${cursor.id}::uuid))`);
      else conditions.push(Prisma.sql`(${distance} > ${cursor.value}::float8 OR (${distance} = ${cursor.value}::float8 AND p.id > ${cursor.id}::uuid))`);
    }
    const where = Prisma.join(conditions, " AND ");
    const order =
      bayesian ? Prisma.sql`ranking_score DESC, ranking_count DESC, p.id ASC`
        : q.sort === "id" ? Prisma.sql`p.id ASC` : q.sort === "distance"
        ? Prisma.sql`distance_km ASC,p.id ASC`
        : q.sort === "name"
          ? Prisma.sql`p.name ASC,p.id ASC`
          : Prisma.sql`p.updated_at DESC,p.id ASC`;
    const markerFields = Prisma.sql`p.id,p.name,p.name_ar,p.name_en,p.latitude,p.longitude,p.category_id,p.updated_at`;
    const compact = !markers && q.compact === "true" && q.details !== "true";
    const cardFields = Prisma.sql`p.area,p.vibe,p.status,p.address,p.price_level`;
    const catalogFields = compact ? cardFields : Prisma.sql`${cardFields},p.description,p.price_min,p.price_max,p.currency,
      p.featured,p.is_active,p.city,p.district,p.phone,p.website,p.opening_hours,
      p.last_synced_at,p.last_seen_at,p.created_at`;
    const pageDetails = markers ? Prisma.empty : Prisma.sql`,${catalogFields},p.cover_image_url`;
    const fields = markers ? markerFields : Prisma.sql`${markerFields},
      ${catalogFields},
      coalesce(nullif(p.cover_image_url,''),image.image_url,'') AS cover_image_url
      ${compact ? Prisma.empty : Prisma.sql`,p.source,p.source_id,p.source_type,
        coalesce(nullif(p.cover_image_url,''),image.image_url,'') AS image_url`}`;
    const coverImage = markers ? Prisma.empty : Prisma.sql`
      LEFT JOIN LATERAL (
        SELECT pi.image_url FROM place_images pi
        WHERE pi.place_id=p.id AND nullif(p.cover_image_url,'') IS NULL
        ORDER BY pi.sort_order,pi.id LIMIT 1
      ) image ON true`;
    const details = !markers && q.details === "true" ? Prisma.sql`
      ,coalesce((SELECT jsonb_agg(jsonb_build_object('image_url', i.image_url, 'caption', i.caption)
        ORDER BY i.sort_order, i.id) FROM place_images i WHERE i.place_id=p.id),'[]'::jsonb) AS place_images
      ,coalesce((SELECT jsonb_agg(jsonb_build_object('day', h.day, 'opens_at', h.opens_at,
        'closes_at', h.closes_at, 'is_closed', h.is_closed)) FROM place_hours h WHERE h.place_id=p.id),'[]'::jsonb) AS place_hours
      ,coalesce((SELECT jsonb_agg(jsonb_build_object('label', pr.label, 'amount', pr.amount,
        'currency', pr.currency)) FROM place_prices pr WHERE pr.place_id=p.id),'[]'::jsonb) AS place_prices
    ` : Prisma.empty;
    const rows = await prisma.$queryRaw<
      any[]
    >`WITH ${bayesian ? Prisma.sql`rating_prior AS MATERIALIZED (${bayesian.globalStatisticsSql()}),` : Prisma.empty}
      page AS MATERIALIZED (
        SELECT ${markerFields},p.branch_name,p.brand_id,p.source,p.source_id,p.source_type,
          ${distance} AS distance_km${pageDetails}
          ${bayesian ? Prisma.sql`,ranking.score AS ranking_score, ranking.count AS ranking_count` : Prisma.empty}
        FROM places p ${ratingJoin} ${rankingJoin}
        WHERE ${where} ORDER BY ${order} LIMIT ${q.limit + 1} OFFSET ${q.offset}
      ), brand_summaries AS MATERIALIZED (
        SELECT b.id,b.name,
          (SELECT count(*)::int FROM places branch
           WHERE branch.brand_id=b.id AND branch.is_active AND branch.status='active') AS branch_count
        FROM (SELECT DISTINCT brand_id FROM page WHERE brand_id IS NOT NULL) brands
        JOIN place_brands b ON b.id=brands.brand_id
      )
      SELECT ${fields},p.id AS branch_id,p.branch_name,p.brand_id,
      b.name AS brand_name,coalesce(b.branch_count,0) AS branch_count,
      ${compact ? Prisma.empty : Prisma.sql`p.source || ':' || coalesce(p.source_type,'') AS external_source,p.source_id AS external_place_id,`}
      to_char(p.updated_at AT TIME ZONE 'UTC','YYYY-MM-DD"T"HH24:MI:SS.US"Z"') AS cursor_updated_at,p.distance_km,
      coalesce((SELECT jsonb_agg(pv.vibe_id ORDER BY pv.vibe_id) FROM place_vibes pv JOIN vibes v ON v.id=pv.vibe_id WHERE pv.place_id=p.id AND v.is_active),'[]'::jsonb) AS vibes,
      ${compact ? Prisma.sql`NULL::jsonb` : Prisma.sql`(SELECT to_jsonb(c) FROM place_categories c WHERE c.id=p.category_id)`} AS category ${details}
      ${markers ? Prisma.empty : Prisma.sql`,to_jsonb(s) AS rating_row`}
      ${bayesian ? Prisma.sql`,p.ranking_score::text AS cursor_rating_score, p.ranking_count,
        g.version AS ranking_version, g.rating_count > 0 AS rating_ranking_available` : Prisma.empty}
      FROM page p LEFT JOIN brand_summaries b ON b.id=p.brand_id
      ${markers ? Prisma.empty : Prisma.sql`LEFT JOIN place_rating_statistics s ON s.place_id=p.id`}
      ${bayesian ? Prisma.sql`RIGHT JOIN rating_prior g ON true` : Prisma.empty}
      ${coverImage} ORDER BY ${order}`;
    if (cursor?.rating && cursor.rating.version !== rows[0]?.ranking_version) {
      throw new ConflictError("Place ratings or prior changed. Restart pagination.");
    }
    // The prior still returns one row when the selected area or filters match nothing.
    const places = rows.filter((row) => row.id !== null);
    const hasMore = places.length > q.limit;
    return {
      places: places.slice(0, q.limit).map(({
        cursor_updated_at, cursor_rating_score, ranking_count, ranking_version,
        rating_ranking_available, ...row
      }) => row),
      pagination: {
        limit: q.limit,
        offset: q.offset,
        has_more: hasMore,
        next_offset: hasMore ? q.offset + q.limit : null,
        next_cursor: hasMore ? encodeCatalogCursor(q, places[q.limit - 1]) : null,
        ...(bayesian && { rating_ranking_available: rows[0]?.rating_ranking_available === true }),
      },
    };
  }
  async geojson(q: CatalogQuery) {
    const result = await this.list(q, true);
    return { collection: { type: "FeatureCollection", features: result.places.filter((p) => Number.isFinite(p.latitude) && Number.isFinite(p.longitude)).map((p) => ({
      type: "Feature", id: p.id, geometry: { type: "Point", coordinates: [p.longitude, p.latitude] },
      properties: { place_id: p.id, branch_id: p.id, brand_id: p.brand_id, brand_name: p.brand_name, branch_name: p.branch_name, branch_count: p.branch_count, name: p.name, name_ar: p.name_ar, name_en: p.name_en, category: p.category_id, vibes: p.vibes, icon: p.category?.icon ?? "place" },
    })) }, pagination: result.pagination };
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
    >`SELECT greatest((SELECT max(updated_at) FROM places),(SELECT max(updated_at) FROM place_categories),(SELECT max(updated_at) FROM vibes),(SELECT max(updated_at) FROM place_brands),(SELECT max(updated_at) FROM place_rating_statistics)) AS version`;
    return row?.version?.toISOString() ?? "empty";
  }
}
