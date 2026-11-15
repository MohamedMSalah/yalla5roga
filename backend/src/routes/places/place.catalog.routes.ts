import { Router } from "express";
import { CatalogController } from "../../controllers/places/catalog.controller.js";
import { authMiddleware } from "../../middleware/auth.middleware.js";
import { requirePlaceCurator } from "../../middleware/place-curator.middleware.js";
const router = Router(),
  controller = new CatalogController();
router.get("/geojson", controller.geojson);
router.get("/licenses", controller.licenses);
router.get("/categories", controller.categories);
router.get("/vibes", controller.vibes);
router.get("/version", controller.version);
router.get(
  "/sync/status",
  authMiddleware,
  requirePlaceCurator,
  controller.status,
);
router.get(
  "/sync/history",
  authMiddleware,
  requirePlaceCurator,
  controller.history,
);
router.post("/sync", authMiddleware, requirePlaceCurator, controller.sync);
export default router;
