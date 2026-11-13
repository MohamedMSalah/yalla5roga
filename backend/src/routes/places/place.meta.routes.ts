import { Router } from "express";
import { PlaceController } from "../../controllers/places/place.controller.js";
import { authMiddleware } from "../../middleware/auth.middleware.js";
import { requirePlaceCurator } from "../../middleware/place-curator.middleware.js";
import { validate } from "../../middleware/validate.middleware.js";
import {
  createPlaceImageBodySchema,
  createPlacePriceBodySchema,
  placeHourIdParamsSchema,
  placeIdParamsSchema,
  placeImageIdParamsSchema,
  placePriceIdParamsSchema,
  upsertPlaceHourBodySchema,
} from "../../validators/places/place.validator.js";

const router = Router();
const controller = new PlaceController();

router.get(
  "/:id/hours",
  validate({ params: placeIdParamsSchema }),
  controller.getHours,
);
router.put(
  "/:id/hours",
  authMiddleware,
  requirePlaceCurator,
  validate({ params: placeIdParamsSchema, body: upsertPlaceHourBodySchema }),
  controller.setHour,
);
router.delete(
  "/:id/hours/:hourId",
  authMiddleware,
  requirePlaceCurator,
  validate({ params: placeHourIdParamsSchema }),
  controller.removeHour,
);

router.get(
  "/:id/images",
  validate({ params: placeIdParamsSchema }),
  controller.getImages,
);
router.post(
  "/:id/images",
  authMiddleware,
  requirePlaceCurator,
  validate({
    params: placeIdParamsSchema,
    body: createPlaceImageBodySchema,
  }),
  controller.addImage,
);
router.delete(
  "/:id/images/:imageId",
  authMiddleware,
  requirePlaceCurator,
  validate({ params: placeImageIdParamsSchema }),
  controller.removeImage,
);

router.get(
  "/:id/prices",
  validate({ params: placeIdParamsSchema }),
  controller.getPrices,
);
router.post(
  "/:id/prices",
  authMiddleware,
  requirePlaceCurator,
  validate({
    params: placeIdParamsSchema,
    body: createPlacePriceBodySchema,
  }),
  controller.addPrice,
);
router.delete(
  "/:id/prices/:priceId",
  authMiddleware,
  requirePlaceCurator,
  validate({ params: placePriceIdParamsSchema }),
  controller.removePrice,
);

export default router;
