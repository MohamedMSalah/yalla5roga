import { prisma } from "../../config/database.js";
import type { TransportationPreferences, SavedTransportationPreference } from "../../types/users/transportation.types.js";
import type { StartingLocationSelection } from "../../types/users/saved-location.types.js";
import { NotFoundError } from "../../utils/errors.js";

const accountFields = { default_transportation_mode: true } as const;
const locationFields = { preferred_transportation_mode: true } as const;

export class TransportationPreferenceRepository {
  constructor(private readonly db = prisma) {}

  async get(userId: string): Promise<TransportationPreferences> {
    const preferences = await this.db.users.findUnique({ where: { id: userId }, select: accountFields });
    if (!preferences) throw new NotFoundError("User");
    return preferences;
  }

  update(userId: string, input: TransportationPreferences): Promise<TransportationPreferences> {
    return this.db.users.update({ where: { id: userId }, data: input, select: accountFields });
  }

  async getForLocation(userId: string, selection: StartingLocationSelection): Promise<SavedTransportationPreference> {
    const id = selection.referenceId;
    const location = selection.source === "saved_location"
      ? await this.db.saved_locations.findUnique({
        where: { user_id_id: { user_id: userId, id } }, select: locationFields,
      })
      : await this.db.saved_places.findUnique({
        where: { user_id_place_id: { user_id: userId, place_id: id } }, select: locationFields,
      });
    if (!location) throw new NotFoundError("Saved location source");
    return location;
  }

  updateBookmark(userId: string, placeId: string, input: SavedTransportationPreference): Promise<SavedTransportationPreference> {
    return this.db.saved_places.update({
      where: { user_id_place_id: { user_id: userId, place_id: placeId } },
      data: input,
      select: locationFields,
    });
  }
}
