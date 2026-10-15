import type {
  CreatePlaceImageInput,
  CreatePlaceInput,
  CreatePlacePriceInput,
  Place,
  PlaceHour,
  PlaceImage,
  PlacePrice,
  UpdatePlaceInput,
  UpsertPlaceHourInput,
} from "../../types/places/place.types.js";

export interface IPlaceRepository {
  findById(id: string): Promise<Place | null>;
  findMany(): Promise<Place[]>;
  findFeatured(): Promise<Place[]>;
  create(data: CreatePlaceInput): Promise<Place>;
  update(id: string, data: UpdatePlaceInput): Promise<Place>;
  delete(id: string): Promise<Place>;

  listHours(placeId: string): Promise<PlaceHour[]>;
  upsertHour(data: UpsertPlaceHourInput): Promise<PlaceHour>;
  deleteHour(id: string): Promise<PlaceHour>;

  listImages(placeId: string): Promise<PlaceImage[]>;
  createImage(data: CreatePlaceImageInput): Promise<PlaceImage>;
  deleteImage(id: string): Promise<PlaceImage>;

  listPrices(placeId: string): Promise<PlacePrice[]>;
  createPrice(data: CreatePlacePriceInput): Promise<PlacePrice>;
  deletePrice(id: string): Promise<PlacePrice>;
}
