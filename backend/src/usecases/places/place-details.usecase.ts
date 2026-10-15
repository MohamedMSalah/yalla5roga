import type { IPlaceRepository } from "../../repositories/places/i-place.repository.js";
import { PlaceRepository } from "../../repositories/places/place.repository.js";
import type {
  CreatePlaceImageInput,
  CreatePlacePriceInput,
  PlaceHour,
  PlaceImage,
  PlacePrice,
  UpsertPlaceHourInput,
} from "../../types/places/place.types.js";
import { NotFoundError, ValidationError } from "../../utils/errors.js";

export class ListPlaceHoursUseCase {
  constructor(
    private readonly places: IPlaceRepository = new PlaceRepository(),
  ) {}

  async execute(placeId: string): Promise<PlaceHour[]> {
    const place = await this.places.findById(placeId);
    if (!place) throw new NotFoundError("Place");
    return this.places.listHours(placeId);
  }
}

export class UpsertPlaceHourUseCase {
  constructor(
    private readonly places: IPlaceRepository = new PlaceRepository(),
  ) {}

  async execute(
    placeId: string,
    data: Omit<UpsertPlaceHourInput, "place_id">,
  ): Promise<PlaceHour> {
    if (!data.day) throw new ValidationError("day is required");
    const place = await this.places.findById(placeId);
    if (!place) throw new NotFoundError("Place");
    return this.places.upsertHour({ ...data, place_id: placeId });
  }
}

export class DeletePlaceHourUseCase {
  constructor(
    private readonly places: IPlaceRepository = new PlaceRepository(),
  ) {}

  execute(id: string): Promise<PlaceHour> {
    return this.places.deleteHour(id);
  }
}

export class ListPlaceImagesUseCase {
  constructor(
    private readonly places: IPlaceRepository = new PlaceRepository(),
  ) {}

  async execute(placeId: string): Promise<PlaceImage[]> {
    const place = await this.places.findById(placeId);
    if (!place) throw new NotFoundError("Place");
    return this.places.listImages(placeId);
  }
}

export class CreatePlaceImageUseCase {
  constructor(
    private readonly places: IPlaceRepository = new PlaceRepository(),
  ) {}

  async execute(
    placeId: string,
    data: Omit<CreatePlaceImageInput, "place_id">,
  ): Promise<PlaceImage> {
    if (!data.image_url) throw new ValidationError("image_url is required");
    const place = await this.places.findById(placeId);
    if (!place) throw new NotFoundError("Place");
    return this.places.createImage({ ...data, place_id: placeId });
  }
}

export class DeletePlaceImageUseCase {
  constructor(
    private readonly places: IPlaceRepository = new PlaceRepository(),
  ) {}

  execute(id: string): Promise<PlaceImage> {
    return this.places.deleteImage(id);
  }
}

export class ListPlacePricesUseCase {
  constructor(
    private readonly places: IPlaceRepository = new PlaceRepository(),
  ) {}

  async execute(placeId: string): Promise<PlacePrice[]> {
    const place = await this.places.findById(placeId);
    if (!place) throw new NotFoundError("Place");
    return this.places.listPrices(placeId);
  }
}

export class CreatePlacePriceUseCase {
  constructor(
    private readonly places: IPlaceRepository = new PlaceRepository(),
  ) {}

  async execute(
    placeId: string,
    data: Omit<CreatePlacePriceInput, "place_id">,
  ): Promise<PlacePrice> {
    if (!data.label || data.amount == null) {
      throw new ValidationError("label and amount are required");
    }
    const place = await this.places.findById(placeId);
    if (!place) throw new NotFoundError("Place");
    return this.places.createPrice({ ...data, place_id: placeId });
  }
}

export class DeletePlacePriceUseCase {
  constructor(
    private readonly places: IPlaceRepository = new PlaceRepository(),
  ) {}

  execute(id: string): Promise<PlacePrice> {
    return this.places.deletePrice(id);
  }
}
