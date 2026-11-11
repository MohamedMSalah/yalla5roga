import { Router } from "express";
import { OutingController } from "../../controllers/outings/outing.controller.js";
import { authMiddleware } from "../../middleware/auth.middleware.js";
import { validate } from "../../middleware/validate.middleware.js";
import { savedOutingParamsSchema } from "../../validators/outings/outing.validator.js";

/**
 * @openapi
 * /api/places/saved:
 *   get:
 *     tags: [Places]
 *     summary: List saved places
 *     description: Returns places saved by the authenticated Firebase UID.
 *     operationId: listSavedPlaces
 *     responses:
 *       "200":
 *         description: Saved place records
 *         content:
 *           application/json:
 *             schema:
 *               $ref: "#/components/schemas/SavedPlaceListResponse"
 *       "401":
 *         $ref: "#/components/responses/Unauthorized"
 * /api/places/{id}/save:
 *   post:
 *     tags: [Places]
 *     summary: Save a place
 *     description: Repeated requests return the existing bookmark.
 *     operationId: savePlace
 *     parameters:
 *       - $ref: "#/components/parameters/UuidId"
 *     responses:
 *       "201":
 *         description: Saved place record
 *         content:
 *           application/json:
 *             schema:
 *               $ref: "#/components/schemas/SavedPlaceResponse"
 *       "401":
 *         $ref: "#/components/responses/Unauthorized"
 *       "400":
 *         $ref: "#/components/responses/BadRequest"
 *       "404":
 *         $ref: "#/components/responses/NotFound"
 *   delete:
 *     tags: [Places]
 *     summary: Unsave a place
 *     operationId: unsavePlace
 *     parameters:
 *       - $ref: "#/components/parameters/UuidId"
 *     responses:
 *       "200":
 *         description: Removed saved-place record
 *         content:
 *           application/json:
 *             schema:
 *               $ref: "#/components/schemas/SavedPlaceResponse"
 *       "401":
 *         $ref: "#/components/responses/Unauthorized"
 *       "400":
 *         $ref: "#/components/responses/BadRequest"
 *       "404":
 *         $ref: "#/components/responses/NotFound"
 */
const router = Router();
const controller = new OutingController();

// Per-route auth only — do not put authMiddleware on the router or it
// intercepts public place list/detail traffic when composed under /api/places.
router.get("/saved", authMiddleware, controller.getSavedPlaces);
router.post(
  "/:id/save",
  authMiddleware,
  validate({ params: savedOutingParamsSchema }),
  controller.savePlaceBookmark,
);
router.delete(
  "/:id/save",
  authMiddleware,
  validate({ params: savedOutingParamsSchema }),
  controller.unsavePlaceBookmark,
);

export default router;
