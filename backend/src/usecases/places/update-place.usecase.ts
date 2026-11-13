import type { IPlaceRepository } from "../../repositories/places/i-place.repository.js";
import { PlaceRepository } from "../../repositories/places/place.repository.js";
import { MediaService } from "../../services/media/media.service.js";
import type {
  Place,
  UpdatePlaceInput,
} from "../../types/places/place.types.js";
import { NotFoundError } from "../../utils/errors.js";

export class UpdatePlaceUseCase {
  constructor(
    private readonly places: IPlaceRepository = new PlaceRepository(),
    private readonly media = new MediaService(),
  ) {}

  async execute(
    id: string,
    data: UpdatePlaceInput,
    callerUid?: string,
  ): Promise<Place> {
    const existing = await this.places.findById(id);
    if (!existing) throw new NotFoundError("Place");

    const patch: UpdatePlaceInput = { ...data };
    if (data.cover_image_url !== undefined) {
      patch.cover_image_url = await this.media.resolveEntityImage({
        uid: callerUid ?? "",
        imageValue: data.cover_image_url,
        purpose: "place",
        link: { place_id: id },
      }) ?? undefined;
    }
    return this.places.update(id, patch);
  }
}
