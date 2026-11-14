import { Router } from "express";
import { OutingController } from "../../controllers/outings/outing.controller.js";
import { validate } from "../../middleware/validate.middleware.js";
import {
  createOutingBodySchema,
  listOutingsQuerySchema,
  outingIdParamsSchema,
  updateOutingBodySchema,
} from "../../validators/outings/outing.validator.js";

/**
 * @openapi
 * /api/outings/cuser:
 *   get:
 *     tags: [Outings]
 *     summary: List my outings
 *     description: >
 *       Uses only the Firebase UID on the Bearer token. Includes outings the
 *       user created, was invited to, or can see through a group membership.
 *     operationId: listCurrentUserOutings
 *     responses:
 *       "200":
 *         description: Outings for the authenticated user
 *         content:
 *           application/json:
 *             schema:
 *               $ref: "#/components/schemas/OutingListResponse"
 *       "401":
 *         $ref: "#/components/responses/Unauthorized"
 *       "500":
 *         $ref: "#/components/responses/InternalServerError"
 * /api/outings:
 *   get:
 *     tags: [Outings]
 *     summary: List outings
 *     description: Lists the caller’s outings. A groupId filter requires active membership and userId, if supplied, must equal the caller UID.
 *     operationId: listOutings
 *     parameters:
 *       - in: query
 *         name: groupId
 *         required: false
 *         schema:
 *           type: string
 *           format: uuid
 *       - in: query
 *         name: userId
 *         required: false
 *         schema:
 *           type: string
 *           minLength: 1
 *     responses:
 *       "200":
 *         description: Outings
 *         content:
 *           application/json:
 *             schema:
 *               $ref: "#/components/schemas/OutingListResponse"
 *       "400":
 *         $ref: "#/components/responses/BadRequest"
 *       "401":
 *         $ref: "#/components/responses/Unauthorized"
 *       "500":
 *         $ref: "#/components/responses/InternalServerError"
 *       "403":
 *         $ref: "#/components/responses/Forbidden"
 *       "404":
 *         $ref: "#/components/responses/NotFound"
 *   post:
 *     tags: [Outings]
 *     summary: Create an outing
 *     description: >
 *       created_by is taken from the authenticated Firebase UID.
 *       Group outings require group_id and active membership (occasion defaults to none).
 *       Special events use birthday, wedding, celebration or other, with optional group_id.
 *       A selected group requires active membership. Type is derived from occasion.
 *     operationId: createOuting
 *     requestBody:
 *       $ref: "#/components/requestBodies/CreateOuting"
 *     responses:
 *       "201":
 *         description: Created outing
 *         content:
 *           application/json:
 *             schema:
 *               $ref: "#/components/schemas/OutingResponse"
 *       "400":
 *         $ref: "#/components/responses/BadRequest"
 *       "401":
 *         $ref: "#/components/responses/Unauthorized"
 *       "500":
 *         $ref: "#/components/responses/InternalServerError"
 *       "403":
 *         $ref: "#/components/responses/Forbidden"
 *       "404":
 *         $ref: "#/components/responses/NotFound"
 *       "409":
 *         description: The request conflicts with the current resource state
 *         content:
 *           application/json:
 *             schema:
 *               $ref: "#/components/schemas/ErrorResponse"
 * /api/outings/{id}/cancel:
 *   post:
 *     tags: [Outings]
 *     summary: Cancel an outing
 *     description: >
 *       Allowed only for the outing creator (`created_by`). Persists the
 *       `cancelled` status, notifies affected participants with the existing
 *       `outing_cancelled` event (the notification row carries the outing and
 *       group IDs used for deep linking), and emits the realtime outing change.
 *       Idempotent: a repeated cancel returns the existing row without a second
 *       notification because the notification event key is stable and unique.
 *     operationId: cancelOuting
 *     parameters:
 *       - $ref: "#/components/parameters/UuidId"
 *     responses:
 *       "200":
 *         description: Cancelled outing
 *         content:
 *           application/json:
 *             schema:
 *               $ref: "#/components/schemas/OutingResponse"
 *       "401":
 *         $ref: "#/components/responses/Unauthorized"
 *       "403":
 *         $ref: "#/components/responses/Forbidden"
 *       "404":
 *         $ref: "#/components/responses/NotFound"
 * /api/outings/{id}:
 *   get:
 *     tags: [Outings]
 *     summary: Get an outing
 *     description: Accessible to the creator, active group members, and pending or accepted outing guests.
 *     operationId: getOuting
 *     parameters:
 *       - $ref: "#/components/parameters/UuidId"
 *     responses:
 *       "200":
 *         description: Outing
 *         content:
 *           application/json:
 *             schema:
 *               $ref: "#/components/schemas/OutingResponse"
 *       "400":
 *         $ref: "#/components/responses/BadRequest"
 *       "401":
 *         $ref: "#/components/responses/Unauthorized"
 *       "404":
 *         $ref: "#/components/responses/NotFound"
 *       "500":
 *         $ref: "#/components/responses/InternalServerError"
 *       "403":
 *         $ref: "#/components/responses/Forbidden"
 *   patch:
 *     tags: [Outings]
 *     summary: Update an outing
 *     description: >
 *       Allowed only for the outing creator (`created_by`).
 *     operationId: updateOuting
 *     parameters:
 *       - $ref: "#/components/parameters/UuidId"
 *     requestBody:
 *       $ref: "#/components/requestBodies/UpdateOuting"
 *     responses:
 *       "200":
 *         description: Updated outing
 *         content:
 *           application/json:
 *             schema:
 *               $ref: "#/components/schemas/OutingResponse"
 *       "400":
 *         $ref: "#/components/responses/BadRequest"
 *       "401":
 *         $ref: "#/components/responses/Unauthorized"
 *       "403":
 *         $ref: "#/components/responses/Forbidden"
 *       "404":
 *         $ref: "#/components/responses/NotFound"
 *       "500":
 *         $ref: "#/components/responses/InternalServerError"
 *   delete:
 *     tags: [Outings]
 *     summary: Delete an outing
 *     description: >
 *       Allowed only for the outing creator (`created_by`).
 *     operationId: deleteOuting
 *     parameters:
 *       - $ref: "#/components/parameters/UuidId"
 *     responses:
 *       "200":
 *         description: Deleted outing
 *         content:
 *           application/json:
 *             schema:
 *               $ref: "#/components/schemas/OutingResponse"
 *       "400":
 *         $ref: "#/components/responses/BadRequest"
 *       "401":
 *         $ref: "#/components/responses/Unauthorized"
 *       "403":
 *         $ref: "#/components/responses/Forbidden"
 *       "404":
 *         $ref: "#/components/responses/NotFound"
 *       "500":
 *         $ref: "#/components/responses/InternalServerError"
 */
const router = Router();
const controller = new OutingController();

// Static `/cuser` before `/:id`.
router.get("/cuser", controller.listForCuser);
router.get(
  "/",
  validate({ query: listOutingsQuerySchema }),
  controller.list,
);
router.post(
  "/",
  validate({ body: createOutingBodySchema }),
  controller.create,
);

router.post(
  "/:id/cancel",
  validate({ params: outingIdParamsSchema }),
  controller.cancel,
);
router.get(
  "/:id",
  validate({ params: outingIdParamsSchema }),
  controller.getById,
);
router.patch(
  "/:id",
  validate({ params: outingIdParamsSchema, body: updateOutingBodySchema }),
  controller.update,
);
router.delete(
  "/:id",
  validate({ params: outingIdParamsSchema }),
  controller.remove,
);

export default router;
