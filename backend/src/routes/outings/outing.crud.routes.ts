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
 *     description: "userId defaults to the authenticated user when omitted."
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
 *   post:
 *     tags: [Outings]
 *     summary: Create an outing
 *     description: >
 *       created_by is taken from the authenticated Firebase UID.
 *       Group outings require group_id (occasion defaults to none).
 *       Special events omit group_id and must set occasion to birthday or wedding.
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
 * /api/outings/{id}/cancel:
 *   post:
 *     tags: [Outings]
 *     summary: Cancel an outing
 *     description: Allowed only for the outing creator (`created_by`).
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
