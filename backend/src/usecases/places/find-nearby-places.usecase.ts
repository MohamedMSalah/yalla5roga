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
    if (
      !Number.isFinite(input.lat) || Math.abs(input.lat) > 90 ||
      !Number.isFinite(input.lng) || Math.abs(input.lng) > 180
    ) {
      throw new ValidationError("lat and lng must be valid coordinates");
    }
    return this.places.findNearby(input);
  }
}
