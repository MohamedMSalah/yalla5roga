import type { IPlaceRepository } from "../../repositories/places/i-place.repository.js";
import { PlaceRepository } from "../../repositories/places/place.repository.js";
import type { Place } from "../../types/places/place.types.js";

export class ListPlacesUseCase {
  constructor(
    private readonly places: IPlaceRepository = new PlaceRepository(),
  ) {}

  execute(featuredOnly = false): Promise<Place[]> {
    if (featuredOnly) return this.places.findFeatured();
    return this.places.findMany();
  }
}
