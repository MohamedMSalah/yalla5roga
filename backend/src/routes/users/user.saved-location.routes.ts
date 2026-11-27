import { Router } from "express";
import { SavedLocationController } from "../../controllers/users/saved-location.controller.js";
import { validate } from "../../middleware/validate.middleware.js";
import {
  savedLocationBodySchema,
  savedLocationIdParamsSchema,
  startingLocationSelectionSchema,
  updateSavedLocationBodySchema,
} from "../../validators/users/saved-location.validator.js";

const router = Router();
const controller = new SavedLocationController();
const locations = "/me/saved-locations";
const item = locations + "/:id";
const startingLocation = "/me/default-starting-location";
const params = savedLocationIdParamsSchema;

router.get(locations, controller.list);
router.post(locations, validate({ body: savedLocationBodySchema }), controller.create);
router.get(item, validate({ params }), controller.get);
router.patch(item, validate({ params, body: updateSavedLocationBodySchema }), controller.update);
router.delete(item, validate({ params }), controller.delete);
router.get(startingLocation, controller.getDefault);
router.put(startingLocation, validate({ body: startingLocationSelectionSchema }), controller.setDefault);
router.delete(startingLocation, controller.clearDefault);

export default router;
