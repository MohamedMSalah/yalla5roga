import { Router } from "express";
import { TransportationPreferencesController } from "../../controllers/users/transportation-preferences.controller.js";
import { validate } from "../../middleware/validate.middleware.js";
import { updateTransportationPreferencesSchema } from "../../validators/users/transportation.validator.js";

const router = Router();
const controller = new TransportationPreferencesController();
const path = "/me/transportation-preferences";

router.get(path, controller.get);
router.patch(path, validate({ body: updateTransportationPreferencesSchema }), controller.update);

export default router;
