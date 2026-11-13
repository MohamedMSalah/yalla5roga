import type { NextFunction, Request, Response } from "express";
import {
  ConfirmMediaUploadUseCase,
  DeleteMediaUseCase,
  GetMediaUrlUseCase,
  GetMediaUrlsUseCase,
} from "../../usecases/media/media.usecases.js";
import { RequestMediaUploadUseCase } from "../../usecases/media/request-upload.usecase.js";
import { UnauthorizedError } from "../../utils/errors.js";

function requireUid(req: Request): string {
  if (!req.user?.uid) throw new UnauthorizedError();
  return req.user.uid;
}

export class MediaController {
  constructor(
    private readonly requestUpload = new RequestMediaUploadUseCase(),
    private readonly confirmUpload = new ConfirmMediaUploadUseCase(),
    private readonly deleteMedia = new DeleteMediaUseCase(),
    private readonly getUrl = new GetMediaUrlUseCase(),
    private readonly getUrls = new GetMediaUrlsUseCase(),
  ) {}

  createUpload = async (req: Request, res: Response, next: NextFunction) => {
    try {
      const uid = requireUid(req);
      const result = await this.requestUpload.execute({
        uid,
        purpose: req.body.purpose,
        mimeType: req.body.mime_type,
        fileSize: req.body.file_size,
        entityId: req.body.entity_id ?? null,
        mediaId: req.body.media_id ?? null,
      });
      res.status(201).json({
        success: true,
        data: {
          media_id: result.asset.id,
          object_key: result.asset.object_key,
          bucket: result.asset.bucket,
          visibility: result.asset.visibility,
          status: result.asset.status,
          upload_url: result.upload_url,
          upload_expires_at: result.upload_expires_at.toISOString(),
          // Stable client reference to send back in entity image fields.
          media_reference: `media://${result.asset.id}`,
        },
      });
    } catch (error) {
      next(error);
    }
  };

  confirm = async (req: Request, res: Response, next: NextFunction) => {
    try {
      const uid = requireUid(req);
      const asset = await this.confirmUpload.execute({ uid, mediaId: req.params.id as string });
      res.json({
        success: true,
        data: {
          media_id: asset.id,
          object_key: asset.object_key,
          visibility: asset.visibility,
          status: asset.status,
          file_size: asset.file_size,
          media_reference: `media://${asset.id}`,
          verified_at: asset.verified_at?.toISOString() ?? null,
        },
      });
    } catch (error) {
      next(error);
    }
  };

  getAssetUrl = async (req: Request, res: Response, next: NextFunction) => {
    try {
      const uid = req.user?.uid ?? null;
      const delivery = await this.getUrl.execute({ uid, mediaId: req.params.id as string });
      res.json({
        success: true,
        data: {
          media_id: delivery.media_id,
          object_key: delivery.object_key,
          url: delivery.url,
          visibility: delivery.visibility,
          expires_at: delivery.expires_at?.toISOString() ?? null,
        },
      });
    } catch (error) {
      next(error);
    }
  };

  getAssetUrls = async (req: Request, res: Response, next: NextFunction) => {
    try {
      const uid = req.user?.uid ?? null;
      const deliveries = await this.getUrls.execute({
        uid,
        mediaIds: req.body.media_ids,
      });
      res.json({
        success: true,
        data: deliveries.map((delivery) => ({
          media_id: delivery.media_id,
          object_key: delivery.object_key,
          url: delivery.url,
          visibility: delivery.visibility,
          expires_at: delivery.expires_at?.toISOString() ?? null,
        })),
      });
    } catch (error) {
      next(error);
    }
  };

  remove = async (req: Request, res: Response, next: NextFunction) => {
    try {
      const uid = requireUid(req);
      await this.deleteMedia.execute({ uid, mediaId: req.params.id as string });
      res.json({ success: true, data: { deleted: true, media_id: req.params.id } });
    } catch (error) {
      next(error);
    }
  };
}
