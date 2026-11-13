import type { MediaAsset } from "../../types/media/media.types.js";
import { MediaService } from "../../services/media/media.service.js";

/** Verifies the object exists in storage and marks the asset ready. */
export class ConfirmMediaUploadUseCase {
  constructor(private readonly service = new MediaService()) {}

  execute(input: { uid: string; mediaId: string }): Promise<MediaAsset> {
    return this.service.confirmUpload(input);
  }
}

/** Owner-only delete of the storage object and its metadata row. */
export class DeleteMediaUseCase {
  constructor(private readonly service = new MediaService()) {}

  async execute(input: { uid: string; mediaId: string }): Promise<void> {
    await this.service.deleteAsset(input);
  }
}

/** Access-checked delivery URL for one asset (signed for private media). */
export class GetMediaUrlUseCase {
  constructor(private readonly service = new MediaService()) {}

  execute(input: { uid: string | null; mediaId: string }) {
    return this.service.getDeliveryUrl(input);
  }
}

/** Batch access-checked delivery URLs (max 50, failures skipped). */
export class GetMediaUrlsUseCase {
  constructor(private readonly service = new MediaService()) {}

  execute(input: { uid: string | null; mediaIds: string[] }) {
    return this.service.getDeliveryUrls(input);
  }
}
