import { Router } from "express";
import { LocationPrivacyController } from "../../controllers/users/location-privacy.controller.js";
import { validate } from "../../middleware/validate.middleware.js";
import {
  grantLocationConsentSchema,
  locationExclusionParamsSchema,
  updateLocationVisibilitySchema,
} from "../../validators/users/location-privacy.validator.js";

const router = Router();
const controller = new LocationPrivacyController();
const privacy = "/me/location-privacy";
const consent = "/me/location-consent";
const groups = consent + "/excluded-groups";
const exclusion = groups + "/:groupId";
const params = locationExclusionParamsSchema;

router.get(privacy, controller.get);
router.patch(privacy, validate({ body: updateLocationVisibilitySchema }), controller.update);
router.put(consent, validate({ body: grantLocationConsentSchema }), controller.grant);
router.delete(consent, controller.withdraw);
router.get(groups, controller.listExclusions);
router.put(exclusion, validate({ params }), controller.exclude);
router.delete(exclusion, validate({ params }), controller.include);

export default router;
