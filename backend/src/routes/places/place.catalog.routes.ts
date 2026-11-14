import { Router } from "express";
import { timingSafeEqual } from "node:crypto";
import { CatalogController } from "../../controllers/places/catalog.controller.js";
import { authMiddleware } from "../../middleware/auth.middleware.js";
import { requirePlaceCurator } from "../../middleware/place-curator.middleware.js";
import { UnauthorizedError } from "../../utils/errors.js";
const router = Router(),
  controller = new CatalogController();
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
// External persistent scheduler only. A distinct server secret cannot grant app curator access.
router.post(
  "/sync/worker",
  (req, res, next) => {
    const expected = process.env.PLACES_SYNC_WORKER_SECRET ?? "",
      actual = req.headers.authorization?.replace(/^Bearer /, "") ?? "";
    if (
      expected.length < 32 ||
      Buffer.byteLength(actual) !== Buffer.byteLength(expected) ||
      !timingSafeEqual(Buffer.from(actual), Buffer.from(expected))
    )
      return next(new UnauthorizedError("Invalid worker credentials"));
    next();
  },
  (req, res, next) => {
    req.body = { dueOnly: true };
    return controller.sync(req, res, next);
  },
);
export default router;
