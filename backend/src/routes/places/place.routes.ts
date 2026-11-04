import { Router } from "express";
import { PlaceController } from "../../controllers/places/place.controller.js";
import { authMiddleware } from "../../middleware/auth.middleware.js";
import { validate } from "../../middleware/validate.middleware.js";
import {
  createPlaceBodySchema,
  createPlaceImageBodySchema,
  createPlacePriceBodySchema,
  listPlacesQuerySchema,
  nearbyPlacesQuerySchema,
  placeHourIdParamsSchema,
  placeIdParamsSchema,
  placeImageIdParamsSchema,
  placePriceIdParamsSchema,
  updatePlaceBodySchema,
  upsertPlaceHourBodySchema,
} from "../../validators/places/place.validator.js";

/**
 * @openapi
 * /api/places/nearby:
 *   get:
 *     tags: [Places]
 *     summary: List nearby places
 *     description: >
 *       Bounding-box search followed by haversine distance. Only places with
 *       `is_active = true` and coordinates are returned, closest first.
 *     operationId: listNearbyPlaces
 *     security: []
 *     parameters:
 *       - in: query
 *         name: lat
 *         required: true
 *         schema: { type: number, minimum: -90, maximum: 90 }
 *       - in: query
 *         name: lng
 *         required: true
 *         schema: { type: number, minimum: -180, maximum: 180 }
 *       - in: query
 *         name: radiusKm
 *         required: false
 *         schema: { type: number, default: 5 }
 *         description: "Clamped to 0.5..50."
 *       - in: query
 *         name: vibe
 *         required: false
 *         schema: { type: string, enum: [food, activity, outdoor, movie] }
 *       - in: query
 *         name: limit
 *         required: false
 *         schema: { type: integer, default: 20, maximum: 50 }
 *       - in: query
 *         name: offset
 *         required: false
 *         schema: { type: integer, default: 0 }
 *     responses:
 *       "200":
 *         description: Nearby places with distance_km
 *         content:
 *           application/json:
 *             schema:
 *               $ref: "#/components/schemas/NearbyPlaceListResponse"
 *       "400":
 *         $ref: "#/components/responses/BadRequest"
 *       "500":
 *         $ref: "#/components/responses/InternalServerError"
 * /api/places:
 *   get:
 *     tags: [Places]
 *     summary: List places
 *     description: Returns places. Optionally filter to featured places only.
 *     operationId: listPlaces
 *     security: []
 *     parameters:
 *       - in: query
 *         name: featured
 *         required: false
 *         schema:
 *           type: string
 *           enum: ["true", "false"]
 *         description: "When true, only featured places are returned."
 *     responses:
 *       "200":
 *         description: Places
 *         content:
 *           application/json:
 *             schema:
 *               $ref: "#/components/schemas/PlaceListResponse"
 *       "400":
 *         $ref: "#/components/responses/BadRequest"
 *       "500":
 *         $ref: "#/components/responses/InternalServerError"
 *   post:
 *     tags: [Places]
 *     summary: Create a place
 *     description: Creates a new place. Requires authentication.
 *     operationId: createPlace
 *     requestBody:
 *       $ref: "#/components/requestBodies/CreatePlace"
 *     responses:
 *       "201":
 *         description: Created place
 *         content:
 *           application/json:
 *             schema:
 *               $ref: "#/components/schemas/PlaceResponse"
 *       "400":
 *         $ref: "#/components/responses/BadRequest"
 *       "401":
 *         $ref: "#/components/responses/Unauthorized"
 *       "500":
 *         $ref: "#/components/responses/InternalServerError"
 * /api/places/{id}:
 *   get:
 *     tags: [Places]
 *     summary: Get a place
 *     description: Returns a single place by UUID. Public.
 *     operationId: getPlace
 *     security: []
 *     parameters:
 *       - $ref: "#/components/parameters/UuidId"
 *     responses:
 *       "200":
 *         description: Place
 *         content:
 *           application/json:
 *             schema:
 *               $ref: "#/components/schemas/PlaceResponse"
 *       "400":
 *         $ref: "#/components/responses/BadRequest"
 *       "404":
 *         $ref: "#/components/responses/NotFound"
 *       "500":
 *         $ref: "#/components/responses/InternalServerError"
 *   patch:
 *     tags: [Places]
 *     summary: Update a place
 *     description: Updates place fields. Requires authentication.
 *     operationId: updatePlace
 *     parameters:
 *       - $ref: "#/components/parameters/UuidId"
 *     requestBody:
 *       $ref: "#/components/requestBodies/UpdatePlace"
 *     responses:
 *       "200":
 *         description: Updated place
 *         content:
 *           application/json:
 *             schema:
 *               $ref: "#/components/schemas/PlaceResponse"
 *       "400":
 *         $ref: "#/components/responses/BadRequest"
 *       "401":
 *         $ref: "#/components/responses/Unauthorized"
 *       "404":
 *         $ref: "#/components/responses/NotFound"
 *       "500":
 *         $ref: "#/components/responses/InternalServerError"
 *   delete:
 *     tags: [Places]
 *     summary: Delete a place
 *     description: Deletes the place. Requires authentication.
 *     operationId: deletePlace
 *     parameters:
 *       - $ref: "#/components/parameters/UuidId"
 *     responses:
 *       "200":
 *         description: Deleted place
 *         content:
 *           application/json:
 *             schema:
 *               $ref: "#/components/schemas/PlaceResponse"
 *       "400":
 *         $ref: "#/components/responses/BadRequest"
 *       "401":
 *         $ref: "#/components/responses/Unauthorized"
 *       "404":
 *         $ref: "#/components/responses/NotFound"
 *       "500":
 *         $ref: "#/components/responses/InternalServerError"
 * /api/places/{id}/hours:
 *   get:
 *     tags: [Places]
 *     summary: List opening hours
 *     description: Returns opening-hours rows for the place. Public.
 *     operationId: listPlaceHours
 *     security: []
 *     parameters:
 *       - $ref: "#/components/parameters/UuidId"
 *     responses:
 *       "200":
 *         description: Opening hours
 *         content:
 *           application/json:
 *             schema:
 *               $ref: "#/components/schemas/PlaceHourListResponse"
 *       "400":
 *         $ref: "#/components/responses/BadRequest"
 *       "404":
 *         $ref: "#/components/responses/NotFound"
 *       "500":
 *         $ref: "#/components/responses/InternalServerError"
 *   put:
 *     tags: [Places]
 *     summary: Upsert opening hours for a weekday
 *     description: Creates or replaces the hours for one weekday. Requires authentication.
 *     operationId: upsertPlaceHour
 *     parameters:
 *       - $ref: "#/components/parameters/UuidId"
 *     requestBody:
 *       $ref: "#/components/requestBodies/UpsertPlaceHour"
 *     responses:
 *       "200":
 *         description: Saved hours
 *         content:
 *           application/json:
 *             schema:
 *               $ref: "#/components/schemas/PlaceHourResponse"
 *       "400":
 *         $ref: "#/components/responses/BadRequest"
 *       "401":
 *         $ref: "#/components/responses/Unauthorized"
 *       "404":
 *         $ref: "#/components/responses/NotFound"
 *       "500":
 *         $ref: "#/components/responses/InternalServerError"
 * /api/places/{id}/hours/{hourId}:
 *   delete:
 *     tags: [Places]
 *     summary: Delete an opening-hours row
 *     description: Deletes one opening-hours row. Requires authentication.
 *     operationId: deletePlaceHour
 *     parameters:
 *       - $ref: "#/components/parameters/UuidId"
 *       - $ref: "#/components/parameters/HourId"
 *     responses:
 *       "200":
 *         description: Deleted hours row
 *         content:
 *           application/json:
 *             schema:
 *               $ref: "#/components/schemas/PlaceHourResponse"
 *       "400":
 *         $ref: "#/components/responses/BadRequest"
 *       "401":
 *         $ref: "#/components/responses/Unauthorized"
 *       "500":
 *         $ref: "#/components/responses/InternalServerError"
 * /api/places/{id}/images:
 *   get:
 *     tags: [Places]
 *     summary: List place images
 *     description: Returns images for the place. Public.
 *     operationId: listPlaceImages
 *     security: []
 *     parameters:
 *       - $ref: "#/components/parameters/UuidId"
 *     responses:
 *       "200":
 *         description: Images
 *         content:
 *           application/json:
 *             schema:
 *               $ref: "#/components/schemas/PlaceImageListResponse"
 *       "400":
 *         $ref: "#/components/responses/BadRequest"
 *       "404":
 *         $ref: "#/components/responses/NotFound"
 *       "500":
 *         $ref: "#/components/responses/InternalServerError"
 *   post:
 *     tags: [Places]
 *     summary: Add a place image
 *     description: Adds an image to the place. Requires authentication.
 *     operationId: createPlaceImage
 *     parameters:
 *       - $ref: "#/components/parameters/UuidId"
 *     requestBody:
 *       $ref: "#/components/requestBodies/CreatePlaceImage"
 *     responses:
 *       "201":
 *         description: Created image
 *         content:
 *           application/json:
 *             schema:
 *               $ref: "#/components/schemas/PlaceImageResponse"
 *       "400":
 *         $ref: "#/components/responses/BadRequest"
 *       "401":
 *         $ref: "#/components/responses/Unauthorized"
 *       "404":
 *         $ref: "#/components/responses/NotFound"
 *       "500":
 *         $ref: "#/components/responses/InternalServerError"
 * /api/places/{id}/images/{imageId}:
 *   delete:
 *     tags: [Places]
 *     summary: Delete a place image
 *     description: Deletes an image from the place. Requires authentication.
 *     operationId: deletePlaceImage
 *     parameters:
 *       - $ref: "#/components/parameters/UuidId"
 *       - $ref: "#/components/parameters/ImageId"
 *     responses:
 *       "200":
 *         description: Deleted image
 *         content:
 *           application/json:
 *             schema:
 *               $ref: "#/components/schemas/PlaceImageResponse"
 *       "400":
 *         $ref: "#/components/responses/BadRequest"
 *       "401":
 *         $ref: "#/components/responses/Unauthorized"
 *       "500":
 *         $ref: "#/components/responses/InternalServerError"
 * /api/places/{id}/prices:
 *   get:
 *     tags: [Places]
 *     summary: List place prices
 *     description: Returns prices for the place. Public.
 *     operationId: listPlacePrices
 *     security: []
 *     parameters:
 *       - $ref: "#/components/parameters/UuidId"
 *     responses:
 *       "200":
 *         description: Prices
 *         content:
 *           application/json:
 *             schema:
 *               $ref: "#/components/schemas/PlacePriceListResponse"
 *       "400":
 *         $ref: "#/components/responses/BadRequest"
 *       "404":
 *         $ref: "#/components/responses/NotFound"
 *       "500":
 *         $ref: "#/components/responses/InternalServerError"
 *   post:
 *     tags: [Places]
 *     summary: Add a place price
 *     description: Adds a price row to the place. Requires authentication.
 *     operationId: createPlacePrice
 *     parameters:
 *       - $ref: "#/components/parameters/UuidId"
 *     requestBody:
 *       $ref: "#/components/requestBodies/CreatePlacePrice"
 *     responses:
 *       "201":
 *         description: Created price
 *         content:
 *           application/json:
 *             schema:
 *               $ref: "#/components/schemas/PlacePriceResponse"
 *       "400":
 *         $ref: "#/components/responses/BadRequest"
 *       "401":
 *         $ref: "#/components/responses/Unauthorized"
 *       "404":
 *         $ref: "#/components/responses/NotFound"
 *       "500":
 *         $ref: "#/components/responses/InternalServerError"
 * /api/places/{id}/prices/{priceId}:
 *   delete:
 *     tags: [Places]
 *     summary: Delete a place price
 *     description: Deletes a price row from the place. Requires authentication.
 *     operationId: deletePlacePrice
 *     parameters:
 *       - $ref: "#/components/parameters/UuidId"
 *       - $ref: "#/components/parameters/PriceId"
 *     responses:
 *       "200":
 *         description: Deleted price
 *         content:
 *           application/json:
 *             schema:
 *               $ref: "#/components/schemas/PlacePriceResponse"
 *       "400":
 *         $ref: "#/components/responses/BadRequest"
 *       "401":
 *         $ref: "#/components/responses/Unauthorized"
 *       "500":
 *         $ref: "#/components/responses/InternalServerError"
 */
const api = Router();
const controller = new PlaceController();

// Static `/nearby` before `/:id` so "nearby" is never treated as a place id.
api.get(
  "/nearby",
  validate({ query: nearbyPlacesQuerySchema }),
  controller.nearby,
);
api.get(
  "/",
  validate({ query: listPlacesQuerySchema }),
  controller.list,
);
api.post(
  "/",
  authMiddleware,
  validate({ body: createPlaceBodySchema }),
  controller.create,
);
api.get(
  "/:id",
  validate({ params: placeIdParamsSchema }),
  controller.getById,
);
api.patch(
  "/:id",
  authMiddleware,
  validate({ params: placeIdParamsSchema, body: updatePlaceBodySchema }),
  controller.update,
);
api.delete(
  "/:id",
  authMiddleware,
  validate({ params: placeIdParamsSchema }),
  controller.remove,
);

// Hours
api.get(
  "/:id/hours",
  validate({ params: placeIdParamsSchema }),
  controller.getHours,
);
api.put(
  "/:id/hours",
  authMiddleware,
  validate({ params: placeIdParamsSchema, body: upsertPlaceHourBodySchema }),
  controller.setHour,
);
api.delete(
  "/:id/hours/:hourId",
  authMiddleware,
  validate({ params: placeHourIdParamsSchema }),
  controller.removeHour,
);

// Images
api.get(
  "/:id/images",
  validate({ params: placeIdParamsSchema }),
  controller.getImages,
);
api.post(
  "/:id/images",
  authMiddleware,
  validate({
    params: placeIdParamsSchema,
    body: createPlaceImageBodySchema,
  }),
  controller.addImage,
);
api.delete(
  "/:id/images/:imageId",
  authMiddleware,
  validate({ params: placeImageIdParamsSchema }),
  controller.removeImage,
);

// Prices
api.get(
  "/:id/prices",
  validate({ params: placeIdParamsSchema }),
  controller.getPrices,
);
api.post(
  "/:id/prices",
  authMiddleware,
  validate({
    params: placeIdParamsSchema,
    body: createPlacePriceBodySchema,
  }),
  controller.addPrice,
);
api.delete(
  "/:id/prices/:priceId",
  authMiddleware,
  validate({ params: placePriceIdParamsSchema }),
  controller.removePrice,
);

const router = Router();
router.use("/api/places", api);

export default router;
