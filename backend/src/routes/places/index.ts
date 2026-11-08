import { Router } from "express";
import placeCrudRoutes from "./place.crud.routes.js";
import placeMetaRoutes from "./place.meta.routes.js";
import placeSavedRoutes from "./place.saved.routes.js";

const api = Router();

// Static `/saved` and `/nearby` before dynamic `/:id`.
api.use(placeSavedRoutes);
api.use(placeCrudRoutes);
api.use(placeMetaRoutes);

const router = Router();
router.use("/api/places", api);

export default router;
