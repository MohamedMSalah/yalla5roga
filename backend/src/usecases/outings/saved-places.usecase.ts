import { prisma } from "../../config/database.js";
import type { IOutingRepository } from "../../repositories/outings/i-outing.repository.js";
import { OutingRepository } from "../../repositories/outings/outing.repository.js";
import type { SavedPlace } from "../../types/outings/outing.types.js";
import { NotFoundError } from "../../utils/errors.js";

export class ListSavedPlacesUseCase {
  constructor(
    private readonly outings: IOutingRepository = new OutingRepository(),
  ) {}

  execute(userId: string): Promise<SavedPlace[]> {
    return this.outings.listSavedPlacesByUser(userId);
  }
}

export class SavePlaceUseCase {
  constructor(
    private readonly outings: IOutingRepository = new OutingRepository(),
  ) {}

  async execute(userId: string, placeId: string): Promise<SavedPlace> {
    const place = await prisma.places.findUnique({ where: { id: placeId } });
    if (!place) throw new NotFoundError("Place");
    return this.outings.savePlace(userId, placeId);
  }
}

export class UnsavePlaceUseCase {
  constructor(
    private readonly outings: IOutingRepository = new OutingRepository(),
  ) {}

  execute(userId: string, placeId: string): Promise<SavedPlace> {
    return this.outings.unsavePlace(userId, placeId);
  }
}
