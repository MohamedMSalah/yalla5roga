import { prisma } from "../../config/database.js";
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

export class PlaceDatasource {
  findById(id: string): Promise<Place | null> {
    return prisma.places.findUnique({ where: { id } });
  }

  findMany(): Promise<Place[]> {
    return prisma.places.findMany({
      where: { is_active: true },
      orderBy: { created_at: "desc" },
    });
  }

  findFeatured(): Promise<Place[]> {
    return prisma.places.findMany({
      where: { featured: true, is_active: true },
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

    // 1 degree of latitude is about 111.32 km; longitude shrinks with cos(lat).
    const latDelta = radiusKm / 111.32;
    const lngDelta = radiusKm / (111.32 * Math.cos((lat * Math.PI) / 180));

    return prisma.$queryRaw<NearbyPlace[]>`
      SELECT * FROM (
        SELECT
          id, name, area, vibe, cover_image_url, price_level,
          price_min, price_max, currency, latitude, longitude,
          6371 * 2 * ASIN(LEAST(1.0, SQRT(
            POWER(SIN(RADIANS(latitude - ${lat}::float8) / 2), 2) +
            COS(RADIANS(${lat}::float8)) * COS(RADIANS(latitude)) *
            POWER(SIN(RADIANS(longitude - ${lng}::float8) / 2), 2)
          ))) AS distance_km
        FROM places
        WHERE is_active = true
          AND latitude  BETWEEN ${lat - latDelta}::float8 AND ${lat + latDelta}::float8
          AND longitude BETWEEN ${lng - lngDelta}::float8 AND ${lng + lngDelta}::float8
          AND (${vibe}::outing_vibe IS NULL OR vibe = ${vibe}::outing_vibe)
      ) AS t
      WHERE distance_km <= ${radiusKm}::float8
      ORDER BY distance_km ASC
      LIMIT ${limit} OFFSET ${offset}
    `;
  }

  create(data: CreatePlaceInput): Promise<Place> {
    return prisma.places.create({ data });
  }

  update(id: string, data: UpdatePlaceInput): Promise<Place> {
    return prisma.places.update({
      where: { id },
      data: { ...data, updated_at: new Date() },
    });
  }

  delete(id: string): Promise<Place> {
    return prisma.places.delete({ where: { id } });
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
        opens_at: data.opens_at,
        closes_at: data.closes_at,
        is_closed: data.is_closed,
      },
    });
  }

  deleteHour(id: string): Promise<PlaceHour> {
    return prisma.place_hours.delete({ where: { id } });
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

  deleteImage(id: string): Promise<PlaceImage> {
    return prisma.place_images.delete({ where: { id } });
  }

  // Prices
  listPrices(placeId: string): Promise<PlacePrice[]> {
    return prisma.place_prices.findMany({ where: { place_id: placeId } });
  }

  createPrice(data: CreatePlacePriceInput): Promise<PlacePrice> {
    return prisma.place_prices.create({ data });
  }

  deletePrice(id: string): Promise<PlacePrice> {
    return prisma.place_prices.delete({ where: { id } });
  }
}
