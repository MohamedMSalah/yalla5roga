import type { IPlaceRepository } from "../../repositories/places/i-place.repository.js";
import { PlaceRepository } from "../../repositories/places/place.repository.js";
import type {
  CreatePlaceInput,
  Place,
} from "../../types/places/place.types.js";
import { ValidationError } from "../../utils/errors.js";

export class CreatePlaceUseCase {
  constructor(
    private readonly places: IPlaceRepository = new PlaceRepository(),
  ) {}

  async execute(input: CreatePlaceInput): Promise<Place> {
    if (!input.name) throw new ValidationError("name is required");
    return this.places.create(input);
  }
}
