import type {
  EffectiveStartingLocation,
  SavedLocation,
  SavedLocationInput,
  StartingLocationSelection,
} from "../../types/users/saved-location.types.js";

export interface ISavedLocationRepository {
  create(userId: string, input: SavedLocationInput): Promise<SavedLocation>;
  list(userId: string): Promise<SavedLocation[]>;
  get(userId: string, id: string): Promise<SavedLocation | null>;
  update(userId: string, id: string, input: Partial<SavedLocationInput>): Promise<SavedLocation>;
  delete(userId: string, id: string): Promise<boolean>;
  getDefault(userId: string): Promise<EffectiveStartingLocation | null>;
  setDefault(userId: string, selection: StartingLocationSelection): Promise<EffectiveStartingLocation>;
  clearDefault(userId: string): Promise<void>;
}
