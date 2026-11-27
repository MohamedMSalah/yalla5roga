import { TransportationPreferenceRepository } from "../../repositories/users/transportation-preference.repository.js";
import type { StartingLocationSelection } from "../../types/users/saved-location.types.js";
import type { TransportationMode } from "../../types/users/transportation.types.js";

export type EffectiveTransportation = {
  mode: TransportationMode | null;
  source: "temporary_override" | "saved_location" | "user_default" | "unspecified";
};

export class EffectiveTransportationResolver {
  constructor(
    private readonly preferences: Pick<TransportationPreferenceRepository, "get" | "getForLocation"> =
      new TransportationPreferenceRepository(),
  ) {}

  resolvePreferences(
    temporaryOverride?: TransportationMode | null,
    selectedLocation?: TransportationMode | null,
    accountDefault?: TransportationMode | null,
  ): EffectiveTransportation {
    if (temporaryOverride != null) return { mode: temporaryOverride, source: "temporary_override" };
    if (selectedLocation != null) return { mode: selectedLocation, source: "saved_location" };
    if (accountDefault != null) return { mode: accountDefault, source: "user_default" };
    return { mode: null, source: "unspecified" };
  }

  /** Resolve from current owner data before building or reusing a planning input. */
  async resolveForOwner(ownerId: string, {
    temporaryOverride,
    selectedLocation,
  }: {
    temporaryOverride?: TransportationMode | null;
    selectedLocation?: StartingLocationSelection | null;
  } = {}): Promise<EffectiveTransportation> {
    if (temporaryOverride != null) {
      return this.resolvePreferences(temporaryOverride);
    }

    if (selectedLocation) {
      const { preferred_transportation_mode: mode } =
        await this.preferences.getForLocation(ownerId, selectedLocation);
      if (mode !== null) return this.resolvePreferences(null, mode);
    }

    const { default_transportation_mode: mode } = await this.preferences.get(ownerId);
    return this.resolvePreferences(null, null, mode);
  }
}
