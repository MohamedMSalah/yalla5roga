import { SavedLocationDataSource } from "../../datasources/users/saved-location.datasource.js";
import type {
  EffectiveStartingLocation,
  SavedLocation,
  SavedLocationInput,
  StartingLocationSelection,
} from "../../types/users/saved-location.types.js";
import type { TransportationMode } from "../../types/users/transportation.types.js";
import { NotFoundError, ValidationError } from "../../utils/errors.js";
import type { ISavedLocationRepository } from "./i-saved-location.repository.js";

type Point = { latitude: number | null; longitude: number | null; name: string };

function withDefault({ _count, ...location }: Omit<SavedLocation, "is_default"> & {
  _count: { defaults: number };
}): SavedLocation {
  return { ...location, is_default: _count.defaults > 0 };
}

function effectivePoint(
  source: EffectiveStartingLocation["source"],
  reference_id: string,
  point: Point,
  approximate_area: string | null,
  location_type: SavedLocationInput["location_type"],
  place_id: string | null,
  preferred_transportation_mode: TransportationMode | null,
): EffectiveStartingLocation | null {
  const { latitude, longitude, name } = point;
  if (
    latitude === null || longitude === null ||
    !Number.isFinite(latitude) || !Number.isFinite(longitude) ||
    Math.abs(latitude) > 90 || Math.abs(longitude) > 180
  ) {
    return null;
  }
  return { source, reference_id, name, latitude, longitude, approximate_area, location_type, place_id, preferred_transportation_mode, is_default: true };
}

type Sources = NonNullable<Awaited<ReturnType<SavedLocationDataSource["getDefault"]>>>;

function projectDefault({ saved_location, saved_place }: Sources) {
  if (saved_location) {
    const { id, approximate_area, location_type, place_id, preferred_transportation_mode } = saved_location;
    return effectivePoint("saved_location", id, saved_location, approximate_area, location_type, place_id, preferred_transportation_mode);
  }
  if (saved_place) {
    const { places, place_id } = saved_place;
    return effectivePoint("saved_place", place_id, places, places.district?.trim() || places.area.trim() || null, "custom", place_id, saved_place.preferred_transportation_mode);
  }
  return null;
}

export class SavedLocationRepository implements ISavedLocationRepository {
  constructor(private readonly source = new SavedLocationDataSource()) {}

  private async validateCatalogLink(id?: string | null) {
    if (id && !await this.source.catalogPlaceExists(id)) throw new NotFoundError("Place");
  }

  async create(userId: string, input: SavedLocationInput) {
    await this.validateCatalogLink(input.place_id);
    return withDefault(await this.source.create(userId, input));
  }

  async list(userId: string) {
    return (await this.source.list(userId)).map(withDefault);
  }

  async get(userId: string, id: string) {
    const location = await this.source.get(userId, id);
    return location ? withDefault(location) : null;
  }

  async update(userId: string, id: string, input: Partial<SavedLocationInput>) {
    await this.validateCatalogLink(input.place_id);
    return withDefault(await this.source.update(userId, id, input));
  }

  async delete(userId: string, id: string) {
    return (await this.source.delete(userId, id)).count > 0;
  }

  async getDefault(userId: string) {
    const row = await this.source.getDefault(userId);
    return row ? projectDefault(row) : null;
  }

  setDefault(userId: string, { source, referenceId }: StartingLocationSelection) {
    return this.source.transaction(async (tx) => {
      const personal = source === "saved_location";
      const saved_location = personal
        ? await this.source.getPersonalPoint(tx, userId, referenceId)
        : null;
      const saved_place = personal
        ? null
        : await this.source.getBookmarkPoint(tx, userId, referenceId);
      if (!saved_location && !saved_place) throw new NotFoundError("Saved location source");
      const effective = projectDefault({ saved_location, saved_place });
      if (!effective) throw new ValidationError("Saved place has no valid coordinates");

      await this.source.upsertDefault(tx, userId, {
        saved_location_id: personal ? referenceId : null,
        saved_place_id: personal ? null : referenceId,
      });
      return effective;
    });
  }

  async clearDefault(userId: string) {
    await this.source.clearDefault(userId);
  }
}
