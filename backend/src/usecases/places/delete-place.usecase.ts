import type { IPlaceRepository } from "../../repositories/places/i-place.repository.js";
import { PlaceRepository } from "../../repositories/places/place.repository.js";
import type { Place } from "../../types/places/place.types.js";
import { NotFoundError } from "../../utils/errors.js";

export class DeletePlaceUseCase {
  constructor(
    private readonly places: IPlaceRepository = new PlaceRepository(),
  ) {}

  async execute(id: string): Promise<Place> {
    const existing = await this.places.findById(id);
    if (!existing) throw new NotFoundError("Place");
    return this.places.delete(id);
  }
}
