import { prepareBranch } from "../../services/places/branch-write.js";
import { Prisma } from "@prisma/client";
import { prisma } from "../../config/database.js";
import { notifyCatalogChanged } from "../../services/places/catalog-notifications.js";
import {
  EARTH_RADIUS_KM, nearbySearchBounds,
} from "../../services/places/nearby-search-bounds.js";
import type {
  CreatePlaceImageInput,
  CreatePlaceInput,
  CreatePlacePriceInput,
  FindNearbyPlacesInput,
  NearbyPlace,
  Place,
  PlaceHour,
  PlaceImage,
  PlacePrice,
  UpdatePlaceInput,
  UpsertPlaceHourInput,
} from "../../types/places/place.types.js";

const MIN_RADIUS_KM = 0.5;
const MAX_RADIUS_KM = 50;
const DEFAULT_RADIUS_KM = 5;
const DEFAULT_LIMIT = 20;
const MAX_LIMIT = 50;

const brandInclude = { brand: { include: { _count: { select: { branches: { where: { is_active: true, status: "active" } } } } } } } as const;
export class PlaceDatasource {
  findById(id: string): Promise<Place | null> {
    return prisma.places.findUnique({ where: { id },
      include: { brand: { include: { _count: { select: { branches: { where: { is_active: true, status: "active" } } } } } }, category: true, place_vibes: { include: { vibe: true } }, place_hours: true, place_prices: true, place_images: { orderBy: { sort_order: "asc" } } },
    });
  }

  findMany(): Promise<Place[]> {
    return prisma.places.findMany({
      where: { is_active: true, status: "active" },
      orderBy: { created_at: "desc" },
    });
  }

  findFeatured(): Promise<Place[]> {
    return prisma.places.findMany({
      where: { featured: true, is_active: true, status: "active" },
      orderBy: { updated_at: "desc" },
    });
  }

  /**
   * Bounding box (served by idx_places_lat_lng) followed by the haversine
   * distance on the surviving rows. Rows without coordinates never match.
   */
  findNearby(opts: FindNearbyPlacesInput): Promise<NearbyPlace[]> {
    const radiusKm = Math.min(
      Math.max(opts.radiusKm ?? DEFAULT_RADIUS_KM, MIN_RADIUS_KM),
      MAX_RADIUS_KM,
    );
    const limit = Math.min(Math.max(opts.limit ?? DEFAULT_LIMIT, 1), MAX_LIMIT);
    const offset = Math.max(opts.offset ?? 0, 0);
    const { lat, lng } = opts;
    const vibe = opts.vibe ?? null;

    const bounds = nearbySearchBounds(lat, lng, radiusKm);
    const longitudeFilter = bounds.longitudes.length
      ? Prisma.sql`(${Prisma.join(
          bounds.longitudes.map(
            ([min, max]) =>
              Prisma.sql`longitude BETWEEN ${min}::float8 AND ${max}::float8`,
          ),
          " OR ",
        )})`
      : Prisma.sql`longitude IS NOT NULL`;

    return prisma.$queryRaw<NearbyPlace[]>`
      SELECT * FROM (
        SELECT
          id, name, area, vibe, cover_image_url, price_level,
          price_min, price_max, currency, latitude, longitude,
          ${EARTH_RADIUS_KM}::float8 * 2 * ASIN(LEAST(1.0, SQRT(
            POWER(SIN(RADIANS(latitude - ${lat}::float8) / 2), 2) +
            COS(RADIANS(${lat}::float8)) * COS(RADIANS(latitude)) *
            POWER(SIN(RADIANS(longitude - ${lng}::float8) / 2), 2)
          ))) AS distance_km
        FROM places
        WHERE is_active = true AND status='active'
          AND latitude BETWEEN ${bounds.latitude[0]}::float8 AND ${bounds.latitude[1]}::float8
          AND ${longitudeFilter}
          AND (${vibe}::outing_vibe IS NULL OR vibe = ${vibe}::outing_vibe)
      ) AS t
      WHERE distance_km <= ${radiusKm}::float8
      ORDER BY distance_km ASC, id ASC
      LIMIT ${limit} OFFSET ${offset}
    `;
  }

  create(data: CreatePlaceInput): Promise<Place> {
    const { vibes, ...input } = data;
    return prisma.$transaction(async (tx) => {
      const { existing, fields } = await prepareBranch(tx, input);
      if (existing) return tx.places.findUniqueOrThrow({ where: { id: existing.id }, include: brandInclude });
      const result = await tx.places.create({ include: brandInclude, data: {
          ...fields,
          manually_managed: true,
          place_vibes: vibes
            ? {
                create: [...new Set(vibes)].map((vibe_id) => ({
                  vibe_id,
                  source: "manual",
                })),
              }
            : undefined,
        },
      });
      await notifyCatalogChanged(tx);
      return result;
    });
  }

  update(id: string, data: UpdatePlaceInput): Promise<Place> {
    const { vibes, brand: _brand, source: _source, source_type: _sourceType, source_id: _sourceId, ...fields } = data;
    return prisma.$transaction(async (tx) => {
      await tx.$queryRaw`SELECT id FROM places WHERE id=${id}::uuid FOR UPDATE`;
      const old = await tx.places.findUniqueOrThrow({ where: { id } });
      if (vibes) await tx.place_vibes.deleteMany({ where: { place_id: id } });
      const result = await tx.places.update({
      include: brandInclude,
      where: { id },
      data: { ...fields,
          manually_managed: true, updated_at: new Date(),
          place_vibes: vibes
            ? {
                create: [...new Set(vibes)].map((vibe_id) => ({
                  vibe_id,
                  source: "manual",
                })),
              }
            : undefined,
        },
      });
      if (data.status && data.status !== old.status)
        await tx.place_status_changes.create({
          data: {
            place_id: id,
            old_status: old.status,
            new_status: data.status,
            evidence: { source: "curator" },
          },
        });
      await notifyCatalogChanged(tx);
      return result;
    });
  }

  delete(id: string): Promise<Place> {
    // Preserve reviews, saved places, voting candidates, outing history and media references.
    return this.update(id, { status: "permanently_closed" });
  }

  // Hours
  listHours(placeId: string): Promise<PlaceHour[]> {
    return prisma.place_hours.findMany({ where: { place_id: placeId } });
  }

  upsertHour(data: UpsertPlaceHourInput): Promise<PlaceHour> {
    return prisma.place_hours.upsert({
      where: {
        place_id_day: { place_id: data.place_id, day: data.day },
      },
      create: data,
      update: {
        source: "manual",
        opens_at: data.opens_at,
        closes_at: data.closes_at,
        is_closed: data.is_closed,
      },
    });
  }

  deleteHour(placeId: string, id: string): Promise<PlaceHour> {
    return prisma.place_hours.delete({ where: { id, place_id: placeId } });
  }

  // Images
  listImages(placeId: string): Promise<PlaceImage[]> {
    return prisma.place_images.findMany({
      where: { place_id: placeId },
      orderBy: { sort_order: "asc" },
    });
  }

  createImage(data: CreatePlaceImageInput): Promise<PlaceImage> {
    return prisma.place_images.create({ data });
  }

  deleteImage(placeId: string, id: string): Promise<PlaceImage> {
    return prisma.place_images.delete({ where: { id, place_id: placeId } });
  }

  // Prices
  listPrices(placeId: string): Promise<PlacePrice[]> {
    return prisma.place_prices.findMany({ where: { place_id: placeId } });
  }

  createPrice(data: CreatePlacePriceInput): Promise<PlacePrice> {
    return prisma.place_prices.create({ data });
  }

  deletePrice(placeId: string, id: string): Promise<PlacePrice> {
    return prisma.place_prices.delete({ where: { id, place_id: placeId } });
  }
}
