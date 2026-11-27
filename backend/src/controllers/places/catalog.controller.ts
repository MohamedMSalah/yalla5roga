import type { Request, Response, NextFunction } from "express";
import { PlaceRatingStatisticsRepository } from "../../repositories/places/place-rating-statistics.repository.js";
import { CatalogUseCase } from "../../usecases/places/catalog.usecase.js";
import { catalogQuerySchema, hasRatingCriteria } from "../../validators/places/catalog.validator.js";
import { CATALOG_ATTRIBUTION } from "../../services/places/import-normalization.js";
import { NotFoundError } from "../../utils/errors.js";
import { z } from "zod";
import { catalogLicenses } from "../../services/places/data-licenses.js";
import { decodeChangeCursor } from "../../services/places/catalog-cursor.js";
import { currentRequest, measure } from "../../monitoring/context.js";

const recommendationQuery = z.object({
  limit: z.coerce.number().int().min(1).max(CatalogUseCase.maxRecommendations).default(8),
  lat: z.string().trim().min(1).transform(Number).pipe(z.number().finite().min(-90).max(90)).optional(),
  lng: z.string().trim().min(1).transform(Number).pipe(z.number().finite().min(-180).max(180)).optional(),
}).refine(({ lat, lng }) => (lat === undefined) === (lng === undefined));

const statistics = new PlaceRatingStatisticsRepository();

export class CatalogController {
  constructor(private readonly catalog = new CatalogUseCase()) {}
  recommendations = async (req: Request, res: Response, next: NextFunction) => {
    try {
      const { limit, lat, lng } = recommendationQuery.parse(req.query);
      const area = lat !== undefined && lng !== undefined ? { lat, lng } : undefined;
      const sample = await this.catalog.recommendations(limit, area);
      const data = await statistics.attach(sample, (row) => row.id as string);
      res.json({ success: true, data });
    } catch (error) { next(error); }
  };
  brand = async (req: Request, res: Response, next: NextFunction) => {
    try {
      const id = z.uuid().parse(req.params.id);
      const row = await this.catalog.brand(id);
      if (!row) throw new NotFoundError("Place brand");
      const { _count, identity_key, ...brand } = row;
      res.json({ success: true, data: { ...brand, branch_count: _count.branches } });
    } catch (error) { next(error); }
  };
  branches = async (req: Request, res: Response, next: NextFunction) => {
    try {
      const id = z.uuid().parse(req.params.id);
      if (!await this.catalog.brand(id)) throw new NotFoundError("Place brand");
      const query = catalogQuerySchema.parse({ ...req.query, brand_id: id });
      if (hasRatingCriteria(query)) res.set("Cache-Control", "no-store");
      const result = await this.catalog.list(query);
      res.json({ success: true, data: result.places, pagination: result.pagination, attribution: CATALOG_ATTRIBUTION });
    } catch (error) { next(error); }
  };
  licenses = (_req: Request, res: Response, next: NextFunction) => {
    try {
      const data = catalogLicenses();
      const cache = currentRequest()?.cache;
      if (cache) res.set("X-Cache-Status", cache);
      res.json({ success: true, data });
    } catch (error) { next(error); }
  };
  list = async (req: Request, res: Response, next: NextFunction) => {
    try {
      const input = catalogQuerySchema.parse(req.query);
      if (hasRatingCriteria(input)) res.set("Cache-Control", "no-store");
      const result = await measure("serviceMs", () => this.catalog.list(input));
      res.setHeader("Link", '</api/places/licenses>; rel="license"');
      res.json({
        success: true,
        data: result.places,
        pagination: result.pagination,
        attribution: CATALOG_ATTRIBUTION,
      });
    } catch (e) {
      next(e);
    }
  };
  geojson = async (req: Request, res: Response, next: NextFunction) => {
    try {
      const query = catalogQuerySchema.parse(req.query);
      if (!query.bbox) throw new Error("geojson_requires_bounds");
      if (hasRatingCriteria(query)) res.set("Cache-Control", "no-store");
      const result = await this.catalog.geojson(query);
      res.setHeader("Link", '</api/places/licenses>; rel="license"');
      res.type("application/geo+json").json({ ...result.collection, pagination: result.pagination, attribution: CATALOG_ATTRIBUTION });
    } catch (error) {
      if (error instanceof Error && error.message === "geojson_requires_bounds") {
        res.status(400).json({ success: false, message: "GeoJSON requires bbox or minLat,minLng,maxLat,maxLng" }); return;
      }
      next(error);
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
  changes = async (req: Request, res: Response, next: NextFunction) => {
    const query = z.object({
      cursor: z.string().max(256).optional().transform((value, ctx) => {
        try { return decodeChangeCursor(value); } catch {
          ctx.addIssue({ code: "custom", message: "Invalid catalog cursor" });
          return z.NEVER;
        }
      }),
      limit: z.coerce.number().int().min(1).max(500).default(250),
    }).strict().safeParse(req.query);
    if (!query.success) {
      res.status(400).json({ success: false, message: "Invalid catalog changes query" });
      return;
    }
    try {
      res.setHeader("Link", '</api/places/licenses>; rel="license"');
      res.json({ success: true, data: await this.catalog.changes(query.data.cursor, query.data.limit) });
    } catch (error) { next(error); }
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
          source: z.enum(["overture", "osm"]).optional(),
          city: z.enum(["cairo", "giza"]).optional(),
        })
        .strict()
        .parse(req.body ?? {});
      res.json({ success: true, data: await this.catalog.sync(q) });
    } catch (e) {
      next(e);
    }
  };
}
