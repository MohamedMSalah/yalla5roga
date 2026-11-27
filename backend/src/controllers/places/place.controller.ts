import type { NextFunction, Request, Response } from "express";
import { CreatePlaceUseCase } from "../../usecases/places/create-place.usecase.js";
import { DeletePlaceUseCase } from "../../usecases/places/delete-place.usecase.js";
import { FindNearbyPlacesUseCase } from "../../usecases/places/find-nearby-places.usecase.js";
import { GetPlaceUseCase } from "../../usecases/places/get-place.usecase.js";
import { ListPlacesUseCase } from "../../usecases/places/list-places.usecase.js";
import {
  CreatePlaceImageUseCase,
  CreatePlacePriceUseCase,
  DeletePlaceHourUseCase,
  DeletePlaceImageUseCase,
  DeletePlacePriceUseCase,
  ListPlaceHoursUseCase,
  ListPlaceImagesUseCase,
  ListPlacePricesUseCase,
  UpsertPlaceHourUseCase,
} from "../../usecases/places/place-details.usecase.js";
import { UpdatePlaceUseCase } from "../../usecases/places/update-place.usecase.js";
import { nearbyPlacesQuerySchema } from "../../validators/places/place.validator.js";
import { catalogQuerySchema, hasRatingCriteria } from "../../validators/places/catalog.validator.js";
import { CatalogController } from "./catalog.controller.js";
import { PlaceRatingStatisticsRepository } from "../../repositories/places/place-rating-statistics.repository.js";
import { publicPlace } from "../../services/places/public-place.js";

const statistics = new PlaceRatingStatisticsRepository();

async function placeData<T extends { id: string }>(place: T) {
  const [rated] = await statistics.attach([place], (row) => row.id);
  return publicPlace(rated!);
}

export class PlaceController {
  constructor(
    private readonly createPlace = new CreatePlaceUseCase(),
    private readonly getPlace = new GetPlaceUseCase(),
    private readonly listPlaces = new ListPlacesUseCase(),
    private readonly findNearby = new FindNearbyPlacesUseCase(),
    private readonly updatePlace = new UpdatePlaceUseCase(),
    private readonly deletePlace = new DeletePlaceUseCase(),
    private readonly listHours = new ListPlaceHoursUseCase(),
    private readonly upsertHour = new UpsertPlaceHourUseCase(),
    private readonly deleteHour = new DeletePlaceHourUseCase(),
    private readonly listImages = new ListPlaceImagesUseCase(),
    private readonly createImage = new CreatePlaceImageUseCase(),
    private readonly deleteImage = new DeletePlaceImageUseCase(),
    private readonly listPrices = new ListPlacePricesUseCase(),
    private readonly createPrice = new CreatePlacePriceUseCase(),
    private readonly deletePrice = new DeletePlacePriceUseCase(),
  ) {}

  list = async (req: Request, res: Response, next: NextFunction) => {
    try {
      return new CatalogController().list(req, res, next);
    } catch (error) {
      next(error);
    }
  };

  nearby = async (req: Request, res: Response, next: NextFunction) => {
    try {
      // The route already validated the query (400 on bad input). Express 5
      // re-parses req.query on each access, so coerce here to get numbers.
      const query = nearbyPlacesQuerySchema.parse(req.query);
      const { CatalogUseCase } = await import("../../usecases/places/catalog.usecase.js");
      const input = catalogQuerySchema.parse({ ...req.query,
        lat: query.lat, lng: query.lng, radiusKm: query.radiusKm ?? 5, limit: query.limit ?? 20, sort: query.sort ?? "distance" });
      const rated = hasRatingCriteria(input);
      if (rated) res.set("Cache-Control", "no-store");
      const result = await new CatalogUseCase().list(input);
      res.json({ success: true, data: result.places, ...(rated && { pagination: result.pagination }) });
    } catch (error) {
      next(error);
    }
  };

  getById = async (req: Request, res: Response, next: NextFunction) => {
    try {
      const place = await this.getPlace.execute(req.params.id as string);
      res.json({ success: true, data: await placeData(place) });
    } catch (error) {
      next(error);
    }
  };

  create = async (req: Request, res: Response, next: NextFunction) => {
    try {
      const place = await this.createPlace.execute(req.body, req.user?.uid);
      res.status(201).json({ success: true, data: await placeData(place) });
    } catch (error) {
      next(error);
    }
  };

  update = async (req: Request, res: Response, next: NextFunction) => {
    try {
      const place = await this.updatePlace.execute(
        req.params.id as string,
        req.body,
        req.user?.uid,
      );
      res.json({ success: true, data: await placeData(place) });
    } catch (error) {
      next(error);
    }
  };

  remove = async (req: Request, res: Response, next: NextFunction) => {
    try {
      const place = await this.deletePlace.execute(req.params.id as string);
      res.json({ success: true, data: await placeData(place) });
    } catch (error) {
      next(error);
    }
  };

  getHours = async (req: Request, res: Response, next: NextFunction) => {
    try {
      const data = await this.listHours.execute(req.params.id as string);
      res.json({ success: true, data });
    } catch (error) {
      next(error);
    }
  };

  setHour = async (req: Request, res: Response, next: NextFunction) => {
    try {
      const data = await this.upsertHour.execute(
        req.params.id as string,
        req.body,
      );
      res.json({ success: true, data });
    } catch (error) {
      next(error);
    }
  };

  removeHour = async (req: Request, res: Response, next: NextFunction) => {
    try {
      const data = await this.deleteHour.execute(
        req.params.id as string,
        req.params.hourId as string,
      );
      res.json({ success: true, data });
    } catch (error) {
      next(error);
    }
  };

  getImages = async (req: Request, res: Response, next: NextFunction) => {
    try {
      const data = await this.listImages.execute(req.params.id as string);
      res.json({ success: true, data });
    } catch (error) {
      next(error);
    }
  };

  addImage = async (req: Request, res: Response, next: NextFunction) => {
    try {
      const data = await this.createImage.execute(
        req.params.id as string,
        req.body,
        req.user?.uid,
      );
      res.status(201).json({ success: true, data });
    } catch (error) {
      next(error);
    }
  };

  removeImage = async (req: Request, res: Response, next: NextFunction) => {
    try {
      const data = await this.deleteImage.execute(
        req.params.id as string,
        req.params.imageId as string,
      );
      res.json({ success: true, data });
    } catch (error) {
      next(error);
    }
  };

  getPrices = async (req: Request, res: Response, next: NextFunction) => {
    try {
      const data = await this.listPrices.execute(req.params.id as string);
      res.json({ success: true, data });
    } catch (error) {
      next(error);
    }
  };

  addPrice = async (req: Request, res: Response, next: NextFunction) => {
    try {
      const data = await this.createPrice.execute(
        req.params.id as string,
        req.body,
      );
      res.status(201).json({ success: true, data });
    } catch (error) {
      next(error);
    }
  };

  removePrice = async (req: Request, res: Response, next: NextFunction) => {
    try {
      const data = await this.deletePrice.execute(
        req.params.id as string,
        req.params.priceId as string,
      );
      res.json({ success: true, data });
    } catch (error) {
      next(error);
    }
  };
}
