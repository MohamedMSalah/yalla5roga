import type { IPlaceRepository } from "../../repositories/places/i-place.repository.js";
import { PlaceRepository } from "../../repositories/places/place.repository.js";
import { MediaService } from "../../services/media/media.service.js";
import type {
  CreatePlaceInput,
  Place,
} from "../../types/places/place.types.js";
import { ValidationError } from "../../utils/errors.js";

export class CreatePlaceUseCase {
  constructor(
    private readonly places: IPlaceRepository = new PlaceRepository(),
    private readonly media = new MediaService(),
  ) {}

  async execute(input: CreatePlaceInput, callerUid?: string): Promise<Place> {
    if (!input.name) throw new ValidationError("name is required");

    // Place media is public: the stored value becomes the CDN URL when real
    // R2/CDN are configured, or a media:// reference in local mock mode.
    const coverImageUrl = await this.media.resolveEntityImage({
      uid: callerUid ?? "",
      imageValue: input.cover_image_url,
      purpose: "place",
    });

    const place = await this.places.create({
      ...input,
      ...(coverImageUrl != null ? { cover_image_url: coverImageUrl } : {}),
    });
    await this.media.linkReference({
      uid: callerUid ?? "",
      imageValue: coverImageUrl,
      link: { place_id: place.id },
    });
    return place;
  }
}
