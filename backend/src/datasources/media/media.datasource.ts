import { prisma } from "../../config/database.js";
import type {
  CreateUploadInput,
  MediaAsset,
  MediaPurpose,
  MediaStatus,
} from "../../types/media/media.types.js";

/** Prisma row type matches the application type 1:1. */
export type MediaAssetRow = MediaAsset;

export class MediaDatasource {
  create(data: CreateUploadInput): Promise<MediaAsset> {
    return prisma.media_assets.create({ data });
  }

  findById(id: string): Promise<MediaAsset | null> {
    return prisma.media_assets.findUnique({ where: { id } });
  }

  findByObjectKey(objectKey: string): Promise<MediaAsset | null> {
    return prisma.media_assets.findUnique({ where: { object_key: objectKey } });
  }

  /**
   * Re-issue state for a pending asset: refresh upload expiry. Rows are never
   * re-used after confirm so a replaced upload cannot hijack a ready object.
   */
  refreshUploadExpiry(id: string, uploadExpiresAt: Date): Promise<MediaAsset> {
    return prisma.media_assets.update({
      where: { id },
      data: { upload_expires_at: uploadExpiresAt, status: "pending" },
    });
  }

  markVerified(id: string, fileSize: number, verifiedAt: Date): Promise<MediaAsset> {
    return prisma.media_assets.update({
      where: { id },
      data: {
        status: "ready",
        file_size: fileSize,
        verified_at: verifiedAt,
        upload_expires_at: null,
      },
    });
  }

  markFailed(id: string): Promise<MediaAsset> {
    return prisma.media_assets.update({
      where: { id },
      data: { status: "failed", upload_expires_at: null },
    });
  }

  /**
   * Attach the asset to an entity. Only one link column is set per purpose;
   * the others are cleared so an asset cannot be linked twice.
   */
  linkToEntity(
    id: string,
    link: { user_id?: string; group_id?: string; outing_id?: string; place_id?: string },
  ): Promise<MediaAsset> {
    return prisma.media_assets.update({
      where: { id },
      data: {
        user_id: link.user_id ?? null,
        group_id: link.group_id ?? null,
        outing_id: link.outing_id ?? null,
        place_id: link.place_id ?? null,
      },
    });
  }

  delete(id: string): Promise<MediaAsset> {
    return prisma.media_assets.delete({ where: { id } });
  }

  /** Pending rows whose upload window elapsed (orphan intents). */
  findExpiredPending(limit: number): Promise<MediaAsset[]> {
    return prisma.media_assets.findMany({
      where: { status: "pending", upload_expires_at: { lt: new Date() } },
      take: limit,
      orderBy: { created_at: "asc" },
    });
  }

  /** Failed rows ready for object + row cleanup. */
  findFailed(limit: number): Promise<MediaAsset[]> {
    return prisma.media_assets.findMany({
      where: { status: "failed" },
      take: limit,
      orderBy: { updated_at: "asc" },
    });
  }
}

export type { MediaPurpose, MediaStatus };
