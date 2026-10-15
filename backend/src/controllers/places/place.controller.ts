import type { NextFunction, Request, Response } from "express";
import { CreatePlaceUseCase } from "../../usecases/places/create-place.usecase.js";
import { DeletePlaceUseCase } from "../../usecases/places/delete-place.usecase.js";
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

export class PlaceController {
  constructor(
    private readonly createPlace = new CreatePlaceUseCase(),
    private readonly getPlace = new GetPlaceUseCase(),
    private readonly listPlaces = new ListPlacesUseCase(),
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
      const featuredOnly = Boolean(req.query.featured);
      const places = await this.listPlaces.execute(featuredOnly);
      res.json({ success: true, data: places });
    } catch (error) {
      next(error);
    }
  };

  getById = async (req: Request, res: Response, next: NextFunction) => {
    try {
      const place = await this.getPlace.execute(req.params.id as string);
      res.json({ success: true, data: place });
    } catch (error) {
      next(error);
    }
  };

  create = async (req: Request, res: Response, next: NextFunction) => {
    try {
      const place = await this.createPlace.execute(req.body);
      res.status(201).json({ success: true, data: place });
    } catch (error) {
      next(error);
    }
  };

  update = async (req: Request, res: Response, next: NextFunction) => {
    try {
      const place = await this.updatePlace.execute(
        req.params.id as string,
        req.body,
      );
      res.json({ success: true, data: place });
    } catch (error) {
      next(error);
    }
  };

  remove = async (req: Request, res: Response, next: NextFunction) => {
    try {
      const place = await this.deletePlace.execute(req.params.id as string);
      res.json({ success: true, data: place });
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
      const data = await this.deleteHour.execute(req.params.hourId as string);
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
      );
      res.status(201).json({ success: true, data });
    } catch (error) {
      next(error);
    }
  };

  removeImage = async (req: Request, res: Response, next: NextFunction) => {
    try {
      const data = await this.deleteImage.execute(
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
        req.params.priceId as string,
      );
      res.json({ success: true, data });
    } catch (error) {
      next(error);
    }
  };
}
