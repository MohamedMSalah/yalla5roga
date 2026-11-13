import { MediaDatasource } from "../../datasources/media/media.datasource.js";
import type {
  CreateUploadInput,
  MediaAsset,
} from "../../types/media/media.types.js";
import type { IMediaRepository } from "./i-media.repository.js";

export class MediaRepository implements IMediaRepository {
  constructor(private readonly datasource = new MediaDatasource()) {}

  create(data: CreateUploadInput): Promise<MediaAsset> {
    return this.datasource.create(data);
  }

  findById(id: string): Promise<MediaAsset | null> {
    return this.datasource.findById(id);
  }

  findByObjectKey(objectKey: string): Promise<MediaAsset | null> {
    return this.datasource.findByObjectKey(objectKey);
  }

  refreshUploadExpiry(id: string, uploadExpiresAt: Date): Promise<MediaAsset> {
    return this.datasource.refreshUploadExpiry(id, uploadExpiresAt);
  }

  markVerified(id: string, fileSize: number, verifiedAt: Date): Promise<MediaAsset> {
    return this.datasource.markVerified(id, fileSize, verifiedAt);
  }

  markFailed(id: string): Promise<MediaAsset> {
    return this.datasource.markFailed(id);
  }

  linkToEntity(
    id: string,
    link: { user_id?: string; group_id?: string; outing_id?: string; place_id?: string },
  ): Promise<MediaAsset> {
    return this.datasource.linkToEntity(id, link);
  }

  delete(id: string): Promise<MediaAsset> {
    return this.datasource.delete(id);
  }

  findExpiredPending(limit: number): Promise<MediaAsset[]> {
    return this.datasource.findExpiredPending(limit);
  }

  findFailed(limit: number): Promise<MediaAsset[]> {
    return this.datasource.findFailed(limit);
  }
}
