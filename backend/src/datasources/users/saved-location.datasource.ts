import { Prisma } from "@prisma/client";
import { prisma } from "../../config/database.js";
import type { SavedLocationInput } from "../../types/users/saved-location.types.js";

const locationFields = {
  id: true,
  name: true,
  location_type: true,
  latitude: true,
  longitude: true,
  approximate_area: true,
  address: true,
  place_id: true,
  preferred_transportation_mode: true,
  created_at: true,
  updated_at: true,
  _count: { select: { defaults: true } },
} satisfies Prisma.saved_locationsSelect;

const pointFields = {
  name: true,
  latitude: true,
  longitude: true,
} as const;

const personalPointFields = {
  id: true,
  ...pointFields,
  approximate_area: true,
  location_type: true,
  place_id: true,
  preferred_transportation_mode: true,
} as const;

const bookmarkPointFields = {
  place_id: true,
  preferred_transportation_mode: true,
  places: {
    select: { ...pointFields, district: true, area: true },
  },
} as const;

export class SavedLocationDataSource {
  constructor(private readonly db = prisma) {}

  catalogPlaceExists(id: string) {
    return this.db.places.findUnique({ where: { id }, select: { id: true } });
  }

  create(userId: string, input: SavedLocationInput) {
    return this.db.saved_locations.create({
      data: { ...input, user_id: userId },
      select: locationFields,
    });
  }

  list(userId: string) {
    return this.db.saved_locations.findMany({
      where: { user_id: userId },
      orderBy: [{ created_at: "desc" }, { id: "asc" }],
      select: locationFields,
    });
  }

  get(userId: string, id: string) {
    return this.db.saved_locations.findUnique({
      where: { user_id_id: { user_id: userId, id } },
      select: locationFields,
    });
  }

  update(userId: string, id: string, input: Partial<SavedLocationInput>) {
    return this.db.saved_locations.update({
      where: { user_id_id: { user_id: userId, id } },
      data: input,
      select: locationFields,
    });
  }

  delete(userId: string, id: string) {
    return this.db.saved_locations.deleteMany({ where: { id, user_id: userId } });
  }

  getDefault(userId: string) {
    return this.db.default_starting_locations.findUnique({
      where: { user_id: userId },
      select: {
        saved_location: { select: personalPointFields },
        saved_place: { select: bookmarkPointFields },
      },
    });
  }

  transaction<T>(execute: (tx: Prisma.TransactionClient) => Promise<T>) {
    return this.db.$transaction(execute);
  }

  getPersonalPoint(tx: Prisma.TransactionClient, userId: string, id: string) {
    return tx.saved_locations.findUnique({
      where: { user_id_id: { user_id: userId, id } },
      select: personalPointFields,
    });
  }

  getBookmarkPoint(tx: Prisma.TransactionClient, userId: string, placeId: string) {
    return tx.saved_places.findUnique({
      where: { user_id_place_id: { user_id: userId, place_id: placeId } },
      select: bookmarkPointFields,
    });
  }

  async upsertDefault(
    tx: Prisma.TransactionClient,
    userId: string,
    sources: Pick<Prisma.default_starting_locationsUncheckedCreateInput, "saved_location_id" | "saved_place_id">,
  ) {
    await tx.default_starting_locations.upsert({
      where: { user_id: userId },
      create: { user_id: userId, ...sources },
      update: sources,
      select: { user_id: true },
    });
  }

  clearDefault(userId: string) {
    return this.db.default_starting_locations.deleteMany({ where: { user_id: userId } });
  }
}
