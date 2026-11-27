import type { SavedTransportationPreference, TransportationMode } from "./transportation.types.js";

export const savedLocationTypes = ["home", "work", "university", "gym", "custom"] as const;
export const startingLocationSources = ["saved_location", "saved_place"] as const;

export type SavedLocationInput = {
  name: string;
  location_type: typeof savedLocationTypes[number];
  latitude: number;
  longitude: number;
  approximate_area?: string | null;
  address?: string | null;
  place_id?: string | null;
  preferred_transportation_mode?: TransportationMode | null;
};

export type SavedLocation = Required<SavedLocationInput> & {
  id: string;
  is_default: boolean;
  created_at: Date;
  updated_at: Date;
};

export type StartingLocationSelection = {
  source: typeof startingLocationSources[number];
  referenceId: string;
};

export type EffectiveStartingLocation = SavedTransportationPreference & {
  source: StartingLocationSelection["source"];
  reference_id: string;
  name: string;
  latitude: number;
  longitude: number;
  approximate_area: string | null;
  location_type: SavedLocationInput["location_type"];
  place_id: string | null;
  is_default: true;
};
