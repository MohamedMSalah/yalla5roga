import type { MediaAsset } from "../../types/media/media.types.js";

/**
 * Persistence contract for media asset metadata. Pure CRUD + lifecycle
 * transitions; policy (ownership, access) lives in the media service.
 */
export interface IMediaRepository {
  create(data: {
    object_key: string;
    bucket: string;
    mime_type: string;
    file_size: number;
    visibility: "public" | "private";
    owner_id: string;
    purpose: "profile" | "group" | "outing" | "place" | "chat";
    upload_expires_at: Date;
  }): Promise<MediaAsset>;
  findById(id: string): Promise<MediaAsset | null>;
  findByObjectKey(objectKey: string): Promise<MediaAsset | null>;
  refreshUploadExpiry(id: string, uploadExpiresAt: Date): Promise<MediaAsset>;
  markVerified(id: string, fileSize: number, verifiedAt: Date): Promise<MediaAsset>;
  markFailed(id: string): Promise<MediaAsset>;
  linkToEntity(
    id: string,
    link: { user_id?: string; group_id?: string; outing_id?: string; place_id?: string },
  ): Promise<MediaAsset>;
  delete(id: string): Promise<MediaAsset>;
  findExpiredPending(limit: number): Promise<MediaAsset[]>;
  findFailed(limit: number): Promise<MediaAsset[]>;
}
