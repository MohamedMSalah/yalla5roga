import type { Request, Response, NextFunction } from "express";
import { CatalogUseCase } from "../../usecases/places/catalog.usecase.js";
import { catalogQuerySchema } from "../../validators/places/catalog.validator.js";
import { OSM_ATTRIBUTION } from "../../services/places/osm.js";
import { z } from "zod";
export class CatalogController {
  constructor(private readonly catalog = new CatalogUseCase()) {}
  list = async (req: Request, res: Response, next: NextFunction) => {
    try {
      const result = await this.catalog.list(
        catalogQuerySchema.parse(req.query),
      );
      res.json({
        success: true,
        data: result.places,
        pagination: result.pagination,
        attribution: OSM_ATTRIBUTION,
      });
    } catch (e) {
      next(e);
    }
  };
  categories = async (_req: Request, res: Response, next: NextFunction) => {
    try {
      res.json({ success: true, data: await this.catalog.categories() });
    } catch (e) {
      next(e);
    }
  };
  vibes = async (_req: Request, res: Response, next: NextFunction) => {
    try {
      res.json({ success: true, data: await this.catalog.vibes() });
    } catch (e) {
      next(e);
    }
  };
  version = async (_req: Request, res: Response, next: NextFunction) => {
    try {
      res.json({
        success: true,
        data: { version: await this.catalog.version() },
      });
    } catch (e) {
      next(e);
    }
  };
  status = async (_req: Request, res: Response, next: NextFunction) => {
    try {
      res.json({ success: true, data: await this.catalog.syncStatus() });
    } catch (e) {
      next(e);
    }
  };
  history = async (req: Request, res: Response, next: NextFunction) => {
    try {
      const q = z
        .object({
          limit: z.coerce.number().int().min(1).max(100).default(20),
          offset: z.coerce.number().int().min(0).default(0),
        })
        .parse(req.query);
      res.json({
        success: true,
        data: await this.catalog.syncHistory(q.limit, q.offset),
      });
    } catch (e) {
      next(e);
    }
  };
  sync = async (req: Request, res: Response, next: NextFunction) => {
    try {
      const q = z
        .object({
          dryRun: z.boolean().optional(),
          limit: z.number().int().positive().optional(),
          dueOnly: z.boolean().optional(),
        })
        .strict()
        .parse(req.body ?? {});
      res.json({ success: true, data: await this.catalog.sync(q) });
    } catch (e) {
      next(e);
    }
  };
}
