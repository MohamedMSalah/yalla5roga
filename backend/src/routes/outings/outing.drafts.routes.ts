import { Router } from "express";
import { OutingController } from "../../controllers/outings/outing.controller.js";
import { validate } from "../../middleware/validate.middleware.js";
import {
  createDraftBodySchema,
  draftIdParamsSchema,
  updateDraftBodySchema,
} from "../../validators/outings/outing.validator.js";

/**
 * @openapi
 * /api/outings/drafts:
 *   get:
 *     tags: [Outing Drafts]
 *     summary: List my outing drafts
 *     description: Returns drafts owned by the authenticated Firebase UID.
 *     operationId: listOutingDrafts
 *     responses:
 *       "200":
 *         description: Drafts
 *         content:
 *           application/json:
 *             schema:
 *               $ref: "#/components/schemas/OutingDraftListResponse"
 *       "401":
 *         $ref: "#/components/responses/Unauthorized"
 *       "500":
 *         $ref: "#/components/responses/InternalServerError"
 *   post:
 *     tags: [Outing Drafts]
 *     summary: Create an outing draft
 *     description: "user_id is taken from the authenticated Firebase UID."
 *     operationId: createOutingDraft
 *     requestBody:
 *       $ref: "#/components/requestBodies/OutingDraft"
 *     responses:
 *       "201":
 *         description: Created draft
 *         content:
 *           application/json:
 *             schema:
 *               $ref: "#/components/schemas/OutingDraftResponse"
 *       "400":
 *         $ref: "#/components/responses/BadRequest"
 *       "401":
 *         $ref: "#/components/responses/Unauthorized"
 *       "500":
 *         $ref: "#/components/responses/InternalServerError"
 * /api/outings/drafts/{id}:
 *   patch:
 *     tags: [Outing Drafts]
 *     summary: Update an outing draft
 *     description: Allowed only for the draft owner.
 *     operationId: updateOutingDraft
 *     parameters:
 *       - $ref: "#/components/parameters/UuidId"
 *     requestBody:
 *       $ref: "#/components/requestBodies/OutingDraft"
 *     responses:
 *       "200":
 *         description: Updated draft
 *         content:
 *           application/json:
 *             schema:
 *               $ref: "#/components/schemas/OutingDraftResponse"
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
 *     tags: [Outing Drafts]
 *     summary: Delete an outing draft
 *     description: Allowed only for the draft owner.
 *     operationId: deleteOutingDraft
 *     parameters:
 *       - $ref: "#/components/parameters/UuidId"
 *     responses:
 *       "200":
 *         description: Deleted draft
 *         content:
 *           application/json:
 *             schema:
 *               $ref: "#/components/schemas/OutingDraftResponse"
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

// Static `/drafts` before `/:id`.
router.get("/drafts", controller.getDrafts);
router.post(
  "/drafts",
  validate({ body: createDraftBodySchema }),
  controller.addDraft,
);
router.patch(
  "/drafts/:id",
  validate({ params: draftIdParamsSchema, body: updateDraftBodySchema }),
  controller.editDraft,
);
router.delete(
  "/drafts/:id",
  validate({ params: draftIdParamsSchema }),
  controller.removeDraft,
);

export default router;
