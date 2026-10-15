import type { IPlaceRepository } from "../../repositories/places/i-place.repository.js";
import { PlaceRepository } from "../../repositories/places/place.repository.js";
import type { Place } from "../../types/places/place.types.js";
import { NotFoundError } from "../../utils/errors.js";

export class GetPlaceUseCase {
  constructor(
    private readonly places: IPlaceRepository = new PlaceRepository(),
  ) {}

  async execute(id: string): Promise<Place> {
    const place = await this.places.findById(id);
    if (!place) throw new NotFoundError("Place");
    return place;
  }
}
