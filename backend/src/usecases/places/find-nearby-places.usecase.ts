import type { IPlaceRepository } from "../../repositories/places/i-place.repository.js";
import { PlaceRepository } from "../../repositories/places/place.repository.js";
import type {
  FindNearbyPlacesInput,
  NearbyPlace,
} from "../../types/places/place.types.js";
import { ValidationError } from "../../utils/errors.js";

export class FindNearbyPlacesUseCase {
  constructor(
    private readonly places: IPlaceRepository = new PlaceRepository(),
  ) {}

  execute(input: FindNearbyPlacesInput): Promise<NearbyPlace[]> {
    if (!Number.isFinite(input.lat) || !Number.isFinite(input.lng)) {
      throw new ValidationError("lat and lng are required");
    }
    return this.places.findNearby(input);
  }
}
