import type { MediaAsset } from "../../types/media/media.types.js";
import type { IMediaRepository } from "../../repositories/media/i-media.repository.js";
import { MediaRepository } from "../../repositories/media/media.repository.js";
import {
  MediaService,
  parseMediaReference,
} from "../../services/media/media.service.js";
import { ValidationError } from "../../utils/errors.js";

/**
 * Issues (or refreshes) a presigned direct-upload URL for the authenticated
 * user. Validation of type/size/permissions happens inside MediaService.
 */
export class RequestMediaUploadUseCase {
  constructor(
    private readonly service = new MediaService(),
    private readonly media: IMediaRepository = new MediaRepository(),
  ) {}

  async execute(input: {
    uid: string;
    purpose: "profile" | "group" | "outing" | "place" | "chat";
    mimeType: string;
    fileSize: number;
    entityId?: string | null;
    mediaId?: string | null;
  }): Promise<{ asset: MediaAsset; upload_url: string; upload_expires_at: Date }> {
    if (input.mediaId && !parseMediaReference(`media://${input.mediaId}`)) {
      throw new ValidationError("mediaId must be a UUID");
    }
    return this.service.requestUpload(input);
  }
}
