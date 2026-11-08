import { Router } from "express";
import { OutingController } from "../../controllers/outings/outing.controller.js";
import { validate } from "../../middleware/validate.middleware.js";
import { savedOutingParamsSchema } from "../../validators/outings/outing.validator.js";

/**
 * @openapi
 * /api/outings/saved:
 *   get:
 *     tags: [Saved Outings]
 *     summary: List saved outings
 *     description: Returns outings saved by the authenticated Firebase UID.
 *     operationId: listSavedOutings
 *     responses:
 *       "200":
 *         description: Saved outing records
 *         content:
 *           application/json:
 *             schema:
 *               $ref: "#/components/schemas/SavedOutingListResponse"
 *       "401":
 *         $ref: "#/components/responses/Unauthorized"
 *       "500":
 *         $ref: "#/components/responses/InternalServerError"
 * /api/outings/{id}/save:
 *   post:
 *     tags: [Saved Outings]
 *     summary: Save an outing
 *     description: Saves the outing for the authenticated user.
 *     operationId: saveOuting
 *     parameters:
 *       - $ref: "#/components/parameters/UuidId"
 *     responses:
 *       "201":
 *         description: Saved outing record
 *         content:
 *           application/json:
 *             schema:
 *               $ref: "#/components/schemas/SavedOutingResponse"
 *       "400":
 *         $ref: "#/components/responses/BadRequest"
 *       "401":
 *         $ref: "#/components/responses/Unauthorized"
 *       "404":
 *         $ref: "#/components/responses/NotFound"
 *       "500":
 *         $ref: "#/components/responses/InternalServerError"
 *   delete:
 *     tags: [Saved Outings]
 *     summary: Unsave an outing
 *     description: Removes the saved-outing record for the authenticated user.
 *     operationId: unsaveOuting
 *     parameters:
 *       - $ref: "#/components/parameters/UuidId"
 *     responses:
 *       "200":
 *         description: Removed saved-outing record
 *         content:
 *           application/json:
 *             schema:
 *               $ref: "#/components/schemas/SavedOutingResponse"
 *       "400":
 *         $ref: "#/components/responses/BadRequest"
 *       "401":
 *         $ref: "#/components/responses/Unauthorized"
 *       "500":
 *         $ref: "#/components/responses/InternalServerError"
 */
const router = Router();
const controller = new OutingController();

// Static `/saved` before `/:id` so "saved" is never treated as an outing id.
router.get("/saved", controller.getSaved);
router.post(
  "/:id/save",
  validate({ params: savedOutingParamsSchema }),
  controller.save,
);
router.delete(
  "/:id/save",
  validate({ params: savedOutingParamsSchema }),
  controller.unsave,
);

export default router;
