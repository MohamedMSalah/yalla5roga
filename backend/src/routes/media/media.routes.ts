import { Router } from "express";
import { MediaController } from "../../controllers/media/media.controller.js";
import { validate } from "../../middleware/validate.middleware.js";
import {
  mediaIdParamsSchema,
  requestUploadBodySchema,
  signedUrlsBodySchema,
} from "../../validators/media/media.validator.js";

/**
 * @openapi
 * /api/media/upload-url:
 *   post:
 *     tags: [Media]
 *     summary: Request a direct-to-R2 upload URL
 *     description: >
 *       Creates a `pending` media asset and returns a short-lived presigned PUT
 *       URL. The client uploads the file bytes directly to Cloudflare R2 (or the
 *       local mock storage routes while R2 credentials are not configured) —
 *       binaries never pass through the API or Neon. When `media_id` is sent the
 *       upload URL is re-issued for that still-pending asset (expired URL retry);
 *       the re-issued intent keeps the stored purpose, so a place asset cannot
 *       be refreshed under another purpose. `place` intents require the caller's
 *       Firebase UID in the server-only `PLACES_CURATOR_UIDS` allowlist (403
 *       otherwise); profile, group, outing, and chat uploads are unchanged.
 *     operationId: requestMediaUploadUrl
 *     requestBody:
 *       $ref: "#/components/requestBodies/MediaUploadRequest"
 *     responses:
 *       "201":
 *         description: Upload intent with a presigned PUT URL
 *         content:
 *           application/json:
 *             schema:
 *               $ref: "#/components/schemas/MediaUploadIntentResponse"
 *       "400":
 *         $ref: "#/components/responses/BadRequest"
 *       "401":
 *         $ref: "#/components/responses/Unauthorized"
 *       "403":
 *         $ref: "#/components/responses/Forbidden"
 *       "404":
 *         $ref: "#/components/responses/NotFound"
 *       "409":
 *         description: The requested asset is not pending or belongs to another user
 *         content:
 *           application/json:
 *             schema:
 *               $ref: "#/components/schemas/ErrorResponse"
 *       "500":
 *         $ref: "#/components/responses/InternalServerError"
 * /api/media/signed-urls:
 *   post:
 *     tags: [Media]
 *     summary: Resolve delivery URLs for up to 50 media assets
 *     description: >
 *       Returns a CDN URL for public assets and a short-lived signed GET URL for
 *       private assets. Every asset is access-checked; assets the caller cannot
 *       view (or that do not exist) are omitted instead of failing the batch.
 *       Clients should cache images by `media_id`, never by the signing URL.
 *     operationId: getMediaDeliveryUrls
 *     requestBody:
 *       $ref: "#/components/requestBodies/MediaSignedUrlsRequest"
 *     responses:
 *       "200":
 *         description: Accessible delivery URLs
 *         content:
 *           application/json:
 *             schema:
 *               $ref: "#/components/schemas/MediaUrlListResponse"
 *       "400":
 *         $ref: "#/components/responses/BadRequest"
 *       "401":
 *         $ref: "#/components/responses/Unauthorized"
 *       "500":
 *         $ref: "#/components/responses/InternalServerError"
 * /api/media/{id}/confirm:
 *   post:
 *     tags: [Media]
 *     summary: Confirm a direct upload
 *     description: >
 *       Heads the object in R2 and marks the asset `ready` only when the object
 *       exists with a non-zero size. A missing object marks the asset `failed`
 *       (retry by requesting a new upload URL). Only the owner may confirm.
 *       Place-purpose assets additionally require a curator account (403).
 *     operationId: confirmMediaUpload
 *     parameters:
 *       - $ref: "#/components/parameters/UuidId"
 *     responses:
 *       "200":
 *         description: Verified asset
 *         content:
 *           application/json:
 *             schema:
 *               $ref: "#/components/schemas/MediaAssetResponse"
 *       "401":
 *         $ref: "#/components/responses/Unauthorized"
 *       "403":
 *         $ref: "#/components/responses/Forbidden"
 *       "404":
 *         $ref: "#/components/responses/NotFound"
 *       "409":
 *         description: Upload missing in storage or already failed
 *         content:
 *           application/json:
 *             schema:
 *               $ref: "#/components/schemas/ErrorResponse"
 *       "500":
 *         $ref: "#/components/responses/InternalServerError"
 * /api/media/{id}/url:
 *   get:
 *     tags: [Media]
 *     summary: Get a delivery URL for one media asset
 *     description: >
 *       Public assets return the permanent CDN URL. Private profile/group/outing
 *       and chat assets return a short-lived signed GET URL after the access
 *       check (group membership, outing participation, or ownership). Unauthorized
 *       callers receive 403; missing or not-ready assets receive 404.
 *     operationId: getMediaDeliveryUrl
 *     parameters:
 *       - $ref: "#/components/parameters/UuidId"
 *     responses:
 *       "200":
 *         description: Delivery URL
 *         content:
 *           application/json:
 *             schema:
 *               $ref: "#/components/schemas/MediaUrlResponse"
 *       "401":
 *         $ref: "#/components/responses/Unauthorized"
 *       "403":
 *         $ref: "#/components/responses/Forbidden"
 *       "404":
 *         $ref: "#/components/responses/NotFound"
 *       "500":
 *         $ref: "#/components/responses/InternalServerError"
 * /api/media/{id}:
 *   delete:
 *     tags: [Media]
 *     summary: Delete a media asset
 *     description: >
 *       Deletes the R2 object and its metadata row. Owner only; other users
 *       receive 404 so asset existence is not leaked. Place-purpose assets
 *       additionally require a curator account (403). Entity image fields that
 *       still reference the asset fall back to their default images on clients.
 *     operationId: deleteMediaAsset
 *     parameters:
 *       - $ref: "#/components/parameters/UuidId"
 *     responses:
 *       "200":
 *         description: Asset deleted
 *         content:
 *           application/json:
 *             schema:
 *               $ref: "#/components/schemas/MediaDeletedResponse"
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
const controller = new MediaController();

// Static paths before dynamic `/:id`.
router.post(
  "/upload-url",
  validate({ body: requestUploadBodySchema }),
  controller.createUpload,
);
router.post(
  "/signed-urls",
  validate({ body: signedUrlsBodySchema }),
  controller.getAssetUrls,
);
router.post(
  "/:id/confirm",
  validate({ params: mediaIdParamsSchema }),
  controller.confirm,
);
router.get(
  "/:id/url",
  validate({ params: mediaIdParamsSchema }),
  controller.getAssetUrl,
);
router.delete(
  "/:id",
  validate({ params: mediaIdParamsSchema }),
  controller.remove,
);

export default router;
