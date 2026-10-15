import { Router } from "express";
import { PlaceController } from "../../controllers/places/place.controller.js";
import { authMiddleware } from "../../middleware/auth.middleware.js";
import { validate } from "../../middleware/validate.middleware.js";
import {
  createPlaceBodySchema,
  createPlaceImageBodySchema,
  createPlacePriceBodySchema,
  listPlacesQuerySchema,
  placeHourIdParamsSchema,
  placeIdParamsSchema,
  placeImageIdParamsSchema,
  placePriceIdParamsSchema,
  updatePlaceBodySchema,
  upsertPlaceHourBodySchema,
} from "../../validators/places/place.validator.js";

/**
 * @openapi
 * /api/places:
 *   get:
 *     tags: [Places]
 *     summary: List places
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
 *     summary: Create or replace the hours for one weekday
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

api.get(
  "/",
  validate({ query: listPlacesQuerySchema }),
  controller.list,
);
api.get(
  "/:id",
  validate({ params: placeIdParamsSchema }),
  controller.getById,
);
api.post(
  "/",
  authMiddleware,
  validate({ body: createPlaceBodySchema }),
  controller.create,
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
