import type { ISavedLocationRepository } from "../../repositories/users/i-saved-location.repository.js";
import { SavedLocationRepository } from "../../repositories/users/saved-location.repository.js";

export class EffectiveStartingLocationResolver {
  constructor(private readonly locations: Pick<ISavedLocationRepository, "getDefault"> = new SavedLocationRepository()) {}

  /** Owner-only projection. Smart Meetup calculations use LocationUsageAuthorizationService. */
  resolveForOwner(ownerId: string) {
    return this.locations.getDefault(ownerId);
  }
}
