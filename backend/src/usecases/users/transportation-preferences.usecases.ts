import type { TransportationPreferenceRepository } from "../../repositories/users/transportation-preference.repository.js";
import type { SavedTransportationPreference, TransportationPreferences } from "../../types/users/transportation.types.js";

export class GetTransportationPreferencesUseCase {
  constructor(private readonly repository: Pick<TransportationPreferenceRepository, "get">) {}

  execute(userId: string) {
    return this.repository.get(userId);
  }
}

export class UpdateTransportationPreferencesUseCase {
  constructor(private readonly repository: Pick<TransportationPreferenceRepository, "update">) {}

  execute(userId: string, input: TransportationPreferences) {
    return this.repository.update(userId, input);
  }
}

export class UpdateBookmarkTransportationPreferenceUseCase {
  constructor(private readonly repository: Pick<TransportationPreferenceRepository, "updateBookmark">) {}

  execute(userId: string, placeId: string, input: SavedTransportationPreference) {
    return this.repository.updateBookmark(userId, placeId, input);
  }
}
