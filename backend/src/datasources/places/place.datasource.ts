import { prisma } from "../../config/database.js";
import type {
  CreatePlaceImageInput,
  CreatePlaceInput,
  CreatePlacePriceInput,
  Place,
  PlaceHour,
  PlaceImage,
  PlacePrice,
  UpdatePlaceInput,
  UpsertPlaceHourInput,
} from "../../types/places/place.types.js";

export class PlaceDatasource {
  findById(id: string): Promise<Place | null> {
    return prisma.places.findUnique({ where: { id } });
  }

  findMany(): Promise<Place[]> {
    return prisma.places.findMany({ orderBy: { created_at: "desc" } });
  }

  findFeatured(): Promise<Place[]> {
    return prisma.places.findMany({
      where: { featured: true },
      orderBy: { updated_at: "desc" },
    });
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
