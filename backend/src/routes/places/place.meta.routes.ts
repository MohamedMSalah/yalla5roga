import { Router } from "express";
import { PlaceController } from "../../controllers/places/place.controller.js";
import { authMiddleware } from "../../middleware/auth.middleware.js";
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
  validate({ params: placeIdParamsSchema, body: upsertPlaceHourBodySchema }),
  controller.setHour,
);
router.delete(
  "/:id/hours/:hourId",
  authMiddleware,
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
  validate({
    params: placeIdParamsSchema,
    body: createPlaceImageBodySchema,
  }),
  controller.addImage,
);
router.delete(
  "/:id/images/:imageId",
  authMiddleware,
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
  validate({
    params: placeIdParamsSchema,
    body: createPlacePriceBodySchema,
  }),
  controller.addPrice,
);
router.delete(
  "/:id/prices/:priceId",
  authMiddleware,
  validate({ params: placePriceIdParamsSchema }),
  controller.removePrice,
);

export default router;
