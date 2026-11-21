import { CatalogController } from "../../controllers/places/catalog.controller.js";
import { Router } from "express";
import { mountRoutes } from "../../monitoring/routes.js";
import placeCrudRoutes from "./place.crud.routes.js";
import placeMetaRoutes from "./place.meta.routes.js";
import placeSavedRoutes from "./place.saved.routes.js";
import placeGeocodingRoutes from "./place.geocoding.routes.js";
import catalogRoutes from "./place.catalog.routes.js";

const api = Router();

// Static `/saved` and `/nearby` before dynamic `/:id`.
api.use(placeSavedRoutes);
api.use(placeGeocodingRoutes);
api.use(catalogRoutes);
api.use(placeCrudRoutes);
api.use(placeMetaRoutes);

const router = Router();
const brands = new CatalogController();
router.get("/api/place-brands/:id/branches", brands.branches);
router.get("/api/place-brands/:id", brands.brand);
mountRoutes(router, "/api/places", api);

export default router;
