import { PlaceDatasource } from "../../datasources/places/place.datasource.js";
import type {
  CreatePlaceImageInput,
  CreatePlaceInput,
  CreatePlacePriceInput,
  FindNearbyPlacesInput,
  Place,
  UpdatePlaceInput,
  UpsertPlaceHourInput,
} from "../../types/places/place.types.js";
import type { IPlaceRepository } from "./i-place.repository.js";

export class PlaceRepository implements IPlaceRepository {
  constructor(private readonly datasource = new PlaceDatasource()) {}

  findById(id: string) {
    return this.datasource.findById(id);
  }
  findMany() {
    return this.datasource.findMany();
  }
  findFeatured() {
    return this.datasource.findFeatured();
  }
  findNearby(opts: FindNearbyPlacesInput) {
    return this.datasource.findNearby(opts);
  }
  create(data: CreatePlaceInput) {
    return this.datasource.create(data);
  }
  update(id: string, data: UpdatePlaceInput) {
    return this.datasource.update(id, data);
  }
  delete(id: string) {
    return this.datasource.delete(id);
  }

  listHours(placeId: string) {
    return this.datasource.listHours(placeId);
  }
  upsertHour(data: UpsertPlaceHourInput) {
    return this.datasource.upsertHour(data);
  }
  deleteHour(placeId: string, id: string) {
    return this.datasource.deleteHour(placeId, id);
  }

  listImages(placeId: string) {
    return this.datasource.listImages(placeId);
  }
  createImage(data: CreatePlaceImageInput) {
    return this.datasource.createImage(data);
  }
  deleteImage(placeId: string, id: string) {
    return this.datasource.deleteImage(placeId, id);
  }

  listPrices(placeId: string) {
    return this.datasource.listPrices(placeId);
  }
  createPrice(data: CreatePlacePriceInput) {
    return this.datasource.createPrice(data);
  }
  deletePrice(placeId: string, id: string) {
    return this.datasource.deletePrice(placeId, id);
  }
}
