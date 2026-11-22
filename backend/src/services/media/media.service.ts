import { errorCode, logger } from "../../monitoring/logger.js";
import { getMediaConfig, type MediaConfig } from "../../config/media.js";
import type { MediaAsset, MediaPurpose, MediaDeliveryUrl } from "../../types/media/media.types.js";
import { AppError, ConflictError, ForbiddenError, NotFoundError, ValidationError } from "../../utils/errors.js";
import type { IMediaRepository } from "../../repositories/media/i-media.repository.js";
import { MediaRepository } from "../../repositories/media/media.repository.js";
import { isPlaceCurator } from "../auth/place-curator.js";
import { getMockStorageAdapter } from "./mock-storage.adapter.js";
import { R2StorageAdapter } from "./r2-storage.adapter.js";
import type { MediaStorageAdapter } from "./storage-adapter.js";
import { assertCanUploadPurpose, assertCanViewMedia } from "./media-access.js";
import { imageMimeTypes, optimizeImage } from "./image-optimization.js";
import { downloadCatalogImage } from "./catalog-image-source.js";

/** Stable reference scheme clients store in entity image fields. */
const MEDIA_REF_PATTERN = /^media:\/\/([0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12})$/;

export function isMediaReference(value: string | null | undefined): boolean {
  return value ? MEDIA_REF_PATTERN.test(value.trim()) : false;
}

export function parseMediaReference(
  value: string | null | undefined,
): string | null {
  const match = value?.trim().match(MEDIA_REF_PATTERN);
  return match ? match[1] : null;
}

export function buildMediaReference(assetId: string): string {
  return `media://${assetId}`;
}

const PURPOSE_VISIBILITY: Record<MediaPurpose, "public" | "private"> = {
  profile: "private",
  group: "private",
  outing: "private",
  chat: "private",
  place: "public",
};

const PURPOSE_KEY_PREFIX: Record<MediaPurpose, string> = {
  profile: "profiles",
  group: "groups",
  outing: "outings",
  place: "places",
  chat: "chat",
};

// Rules apply to stored rows too, including older metadata and imports.
const PLACE_OBJECT_KEY = /^places\/(?:[a-zA-Z0-9_-]+\/)*[a-zA-Z0-9_-]+\.(?:jpg|jpeg|png|webp|gif)$/;
const UPLOAD_PREFIX = "uploads/";
const verifying = new Map<string, Promise<MediaAsset>>();

function extensionFor(mimeType: string): string {
  switch (mimeType) {
    case "image/jpeg":
      return "jpg";
    case "image/png":
      return "png";
    case "image/webp":
      return "webp";
    case "image/gif":
      return "gif";
    default:
      return "bin";
  }
}

/**
 * Media Storage Service — single entry point for the upload lifecycle,
 * delivery URLs and cleanup. Storage itself is pluggable
 * (`MediaStorageAdapter`); clients PUT directly to storage. The API only reads
 * bounded staging bytes to verify them and write a server-owned delivery key.
 */
export class MediaService {
  constructor(
    private readonly media: IMediaRepository = new MediaRepository(),
    private readonly config: MediaConfig = getMediaConfig(),
    private readonly adapterOverride?: MediaStorageAdapter,
  ) {}

  private readonly adapters = new Map<string, MediaStorageAdapter>();

  storage(bucket = this.config.r2.bucket ?? "mock-bucket"): MediaStorageAdapter {
    if (this.adapterOverride) return this.adapterOverride;
    let adapter = this.adapters.get(bucket);
    if (!adapter) {
      if (this.config.provider === "r2") {
        const { accountId, accessKeyId, secretAccessKey, endpoint, publicBucket } = this.config.r2;
        if (!accountId || !accessKeyId || !secretAccessKey ||
          (bucket !== this.config.r2.bucket && bucket !== publicBucket)) {
          throw new AppError(503, "Media storage unavailable");
        }
        adapter = new R2StorageAdapter({
          accountId, accessKeyId, secretAccessKey, endpoint, bucket, privateReads: bucket !== publicBucket,
        });
      } else {
        if (process.env.NODE_ENV === "production") throw new AppError(503, "Media storage unavailable");
        adapter = getMockStorageAdapter(this.config.mockBaseUrl);
      }
      this.adapters.set(bucket, adapter);
    }
    return adapter;
  }

  private usesPublicBucket(asset: Pick<MediaAsset, "purpose" | "visibility" | "object_key" | "bucket">): boolean {
    return Boolean(this.config.r2.publicBucket && asset.bucket === this.config.r2.publicBucket &&
      asset.bucket !== this.config.r2.bucket && asset.purpose === "place" &&
      asset.visibility === "public" && PLACE_OBJECT_KEY.test(asset.object_key));
  }

  private storageFor(asset: Pick<MediaAsset, "purpose" | "visibility" | "object_key" | "bucket">) {
    if (asset.bucket === this.config.r2.publicBucket && !this.usesPublicBucket(asset)) {
      throw new NotFoundError("Media asset");
    }
    return this.storage(asset.bucket);
  }

  private publicUrl(asset: MediaAsset): string | null {
    return this.config.provider === "r2" && this.config.publicBaseUrlConfigured && this.usesPublicBucket(asset)
      ? `${this.config.publicBaseUrl}/${asset.object_key}`
      : null;
  }

  /**
   * Reference stored in entity image columns: the CDN URL when real R2 +
   * CDN are configured, otherwise the stable `media://` reference so mock
   * mode still resolves through the backend.
   */
  storageReferenceFor(asset: MediaAsset): string {
    return this.publicUrl(asset) ?? buildMediaReference(asset.id);
  }

  /**
   * Step 1 of the direct-upload flow: create (or refresh) a pending asset row
   * and presign a direct PUT to R2. The client uploads straight to object
   * storage — the backend never proxies bytes.
   */
  async requestUpload(input: {
    uid: string;
    purpose: MediaPurpose;
    mimeType: string;
    fileSize: number;
    entityId?: string | null;
    /** Re-issue a fresh URL for an existing pending asset after expiry. */
    mediaId?: string | null;
  }): Promise<{ asset: MediaAsset; upload_url: string; upload_expires_at: Date }> {
    const { uid, purpose, entityId = null } = input;

    if (!imageMimeTypes.includes(input.mimeType) || !this.config.allowedMimeTypes.includes(input.mimeType)) {
      throw new ValidationError(`Unsupported media type ${input.mimeType}`);
    }
    if (!Number.isSafeInteger(input.fileSize) || input.fileSize <= 0) {
      throw new ValidationError("fileSize must be a positive number");
    }
    if (input.fileSize > this.config.maxUploadBytes) {
      throw new ValidationError(
        `File exceeds the ${Math.floor(this.config.maxUploadBytes / (1024 * 1024))} MB upload limit`,
      );
    }

    await assertCanUploadPurpose({ purpose, entityId, uid });

    let asset: MediaAsset;
    if (input.mediaId) {
      const existing = await this.media.findById(input.mediaId);
      if (!existing) throw new NotFoundError("Media asset");
      if (existing.owner_id !== uid) throw new ConflictError("Media asset belongs to another user");
      if (existing.status !== "pending") {
        throw new ConflictError("Only pending uploads can be refreshed");
      }
      // A refresh must keep the stored purpose. Otherwise a caller could mint a
      // URL for a place-purpose object key while claiming a purpose they are
      // allowed to use.
      if (existing.purpose !== purpose) {
        throw new ValidationError(
          `Media asset purpose mismatch: stored ${existing.purpose}, requested ${purpose}`,
        );
      }
      this.stagingStorage(existing);
      if (existing.file_size !== input.fileSize || existing.mime_type !== input.mimeType) {
        throw new ValidationError("Refreshed uploads must match the original file size and type");
      }
      asset = await this.media.refreshUploadExpiry(
        existing.id,
        new Date(Date.now() + this.config.uploadUrlTtlSeconds * 1000),
      );
    } else {
      const key = UPLOAD_PREFIX + this.buildObjectKey(purpose, input.mimeType);
      const bucket = this.config.r2.bucket ?? "mock-bucket";
      this.storage(bucket);
      asset = await this.media.create({
        object_key: key,
        bucket,
        mime_type: input.mimeType,
        file_size: input.fileSize,
        visibility: PURPOSE_VISIBILITY[purpose],
        owner_id: uid,
        purpose,
        upload_expires_at: new Date(Date.now() + this.config.uploadUrlTtlSeconds * 1000),
      });
    }

    const presigned = await this.stagingStorage(asset).createPresignedPutUrl({
      key: asset.object_key,
      contentType: asset.mime_type,
      contentLength: input.fileSize,
      ttlSeconds: this.config.uploadUrlTtlSeconds,
    });

    return { asset, upload_url: presigned.url, upload_expires_at: presigned.expiresAt };
  }

  /**
   * Step 2: verify and promote a snapshot of private staging bytes. A PUT URL
   * can be replayed until expiry, but it can never overwrite the delivery key.
   */
  async confirmUpload(input: { uid: string; mediaId: string }): Promise<MediaAsset> {
    const asset = await this.getOwnedAssetOrNotFound(input.uid, input.mediaId);
    this.assertCatalogWriteAccess(asset, input.uid);

    if (asset.status === "ready") return asset;
    if (asset.status === "failed") {
      throw new ConflictError("Upload already failed; request a new upload URL");
    }

    const existing = verifying.get(asset.id);
    if (existing) return existing;
    if (verifying.size >= 2) throw new AppError(503, "Image validation busy; try again");
    const work = this.promoteUpload(asset).finally(() => verifying.delete(asset.id));
    verifying.set(asset.id, work);
    return work;
  }

  private stagingStorage(asset: MediaAsset): MediaStorageAdapter {
    if (!asset.object_key.startsWith(UPLOAD_PREFIX) || asset.bucket !== (this.config.r2.bucket ?? "mock-bucket")) {
      throw new ConflictError("Request a new upload URL for this legacy upload");
    }
    return this.storage(asset.bucket);
  }

  private async promoteUpload(asset: MediaAsset): Promise<MediaAsset> {
    const staging = this.stagingStorage(asset);
    if (!asset.upload_expires_at || Date.now() >= asset.upload_expires_at.getTime()) {
      throw new ConflictError("Upload window expired; request a new upload URL");
    }
    const stat = await staging.stat(asset.object_key);
    if (!stat || stat.size !== asset.file_size || stat.contentType !== asset.mime_type) {
      await this.rejectUpload(asset, staging);
      throw new ConflictError("Uploaded object was not found in storage or did not match the upload intent");
    }
    const bytes = await staging.read(asset.object_key, Math.min(asset.file_size, this.config.maxUploadBytes));
    if (!bytes || bytes.length !== asset.file_size) {
      await this.rejectUpload(asset, staging);
      throw new ValidationError("Uploaded image size does not match the upload intent");
    }
    let optimized: Awaited<ReturnType<typeof optimizeImage>>;
    try {
      optimized = await optimizeImage(bytes, asset.mime_type, this.config.maxUploadBytes);
    } catch (error) {
      if (error instanceof ValidationError) await this.rejectUpload(asset, staging);
      throw error;
    }
    const bucket = (asset.purpose === "place" ? this.config.r2.publicBucket : null) ?? asset.bucket;
    const object = {
      bucket, object_key: this.buildObjectKey(asset.purpose, optimized.mimeType),
      mime_type: optimized.mimeType, file_size: optimized.bytes.length,
    };
    const storage = this.storageFor({ ...asset, ...object });
    try {
      await storage.write(object.object_key, optimized.bytes, optimized.mimeType);
    } catch (error) {
      await this.removeStaging(storage, object.object_key);
      throw error;
    }
    let result: MediaAsset;
    try {
      result = await this.media.markVerified(asset.id, object, new Date());
    } catch (error) {
      // If the write outcome is ambiguous, keep its object until readback.
      const current = await this.media.findById(asset.id);
      if (current?.object_key === object.object_key) return current;
      await this.removeStaging(storage, object.object_key);
      if (current?.status === "ready") return current;
      throw error;
    }
    await this.removeStaging(staging, asset.object_key);
    return result;
  }

  private async rejectUpload(asset: MediaAsset, staging: MediaStorageAdapter): Promise<void> {
    await this.media.markFailed(asset.id);
    await this.removeStaging(staging, asset.object_key);
  }

  private async removeStaging(storage: MediaStorageAdapter, key: string): Promise<void> {
    try { await storage.delete(key); }
    catch (error) { logger.warn({ errorCode: errorCode(error) }, "Media object cleanup deferred"); }
  }

  async importCatalogImage(uid: string, source: string): Promise<MediaAsset> {
    await assertCanUploadPurpose({ uid, purpose: "place", entityId: null });
    if (this.config.provider !== "r2") throw new AppError(503, "Configure R2 before importing catalog images");
    const download = await downloadCatalogImage(source, this.config.maxUploadBytes);
    const image = await optimizeImage(download.bytes, download.mimeType, this.config.maxUploadBytes);
    const { asset } = await this.requestUpload({
      uid, purpose: "place", mimeType: image.mimeType, fileSize: image.bytes.length,
    });
    const storage = this.stagingStorage(asset);
    await storage.write(asset.object_key, image.bytes, image.mimeType);
    return this.confirmUpload({ uid, mediaId: asset.id });
  }

  async deleteAsset(input: { uid: string; mediaId: string }): Promise<void> {
    const asset = await this.getOwnedAssetOrNotFound(input.uid, input.mediaId);
    this.assertCatalogWriteAccess(asset, input.uid);
    if (asset.upload_expires_at && asset.upload_expires_at.getTime() > Date.now()) {
      throw new ConflictError("Wait for the upload URL to expire before deleting this media");
    }
    await this.storageFor(asset).delete(asset.object_key);
    await this.media.delete(asset.id);
  }

  /** Single delivery URL after an access check (private → short-lived signed). */
  async getDeliveryUrl(input: { uid: string | null; mediaId: string }): Promise<MediaDeliveryUrl> {
    const asset = await this.media.findById(input.mediaId);
    if (!asset) throw new NotFoundError("Media asset");
    if (asset.status !== "ready") throw new NotFoundError("Media asset");
    await assertCanViewMedia(asset, input.uid);
    return this.deliveryUrlFor(asset);
  }

  /** Batch variant for feeds. Unauthorized assets are simply omitted. */
  async getDeliveryUrls(input: {
    uid: string | null;
    mediaIds: string[];
  }): Promise<MediaDeliveryUrl[]> {
    const unique = [...new Set(input.mediaIds)].slice(0, 50);
    const results: MediaDeliveryUrl[] = [];
    for (const mediaId of unique) {
      try {
        results.push(await this.getDeliveryUrl({ uid: input.uid, mediaId }));
      } catch (error) {
        // Skip missing/inaccessible assets instead of failing the whole batch.
        if (!(error instanceof NotFoundError || error instanceof ForbiddenError)) throw error;
      }
    }
    return results;
  }

  /**
   * Public assets resolve to the CDN base URL (cacheable, no expiry).
   * Private assets resolve to a short-lived signed GET URL — either a real
   * R2 presigned URL or the mock download route in development.
   */
  async deliveryUrlFor(asset: MediaAsset): Promise<MediaDeliveryUrl> {
    const publicUrl = this.publicUrl(asset);
    if (publicUrl) {
      return {
        media_id: asset.id,
        object_key: asset.object_key,
        url: publicUrl,
        visibility: "public",
        expires_at: null,
      };
    }
    const presigned = await this.storageFor(asset).createPresignedGetUrl({
      key: asset.object_key,
      ttlSeconds: this.config.signedGetUrlTtlSeconds,
    });
    return {
      media_id: asset.id,
      object_key: asset.object_key,
      url: presigned.url,
      visibility: asset.visibility,
      expires_at: presigned.expiresAt,
    };
  }

  /**
   * Resolve an entity `image_url` value at write time:
   * - `media://<id>` → verify ownership/readiness, link the asset and return
   *   the reference to persist (CDN URL for public, `media://` for private).
   * - absolute http(s) URL → passed through unchanged (backward compatible).
   * - empty/other values → passed through so entity defaults keep working.
   */
  async resolveEntityImage(input: {
    uid: string;
    imageValue: string | null | undefined;
    purpose: MediaPurpose;
    link?: { user_id?: string; group_id?: string; outing_id?: string; place_id?: string };
  }): Promise<string | null | undefined> {
    const raw = input.imageValue;
    if (raw == null || raw === "") return raw;
    const assetId = parseMediaReference(raw);
    if (!assetId) {
      const url = URL.parse(raw);
      if (url && (url.hostname === URL.parse(this.config.r2.endpoint ?? "")?.hostname ||
        url.searchParams.has("X-Amz-Signature"))) {
        throw new ValidationError("Use a media reference for signed storage images");
      }
      return raw;
    }

    // Defense in depth: the place catalog routes are curator-gated, but the
    // attach path must never let a non-curator link a place-purpose asset.
    if (input.purpose === "place" && !isPlaceCurator(input.uid)) {
      throw new ForbiddenError("Place media requires a curator account");
    }

    const asset = await this.media.findById(assetId);
    if (!asset) throw new NotFoundError("Media asset");
    if (asset.owner_id !== input.uid) {
      throw new ConflictError("Media asset belongs to another user");
    }
    if (asset.status !== "ready") {
      throw new ValidationError("Media upload is not confirmed yet");
    }
    if (asset.purpose !== input.purpose) {
      throw new ValidationError(
        `Media asset was uploaded for ${asset.purpose} and cannot be used as ${input.purpose}`,
      );
    }
    if (input.link) {
      await this.media.linkToEntity(asset.id, input.link);
    }
    return this.storageReferenceFor(asset);
  }

  /**
   * Attach a media reference to an entity after the row exists. Silently
   * ignores plain URLs and assets the caller does not own.
   */
  async linkReference(input: {
    uid: string;
    imageValue: string | null | undefined;
    link: { user_id?: string; group_id?: string; outing_id?: string; place_id?: string };
  }): Promise<void> {
    const assetId = parseMediaReference(input.imageValue);
    if (!assetId) return;
    const asset = await this.media.findById(assetId);
    if (!asset || asset.owner_id !== input.uid || asset.status !== "ready") return;
    await this.media.linkToEntity(asset.id, input.link);
  }

  /**
   * Orphan cleanup: pending intents past their upload window and failed
   * verifications. Removes the storage object (if any) then the row.
   */
  async cleanupExpired(limit = 100): Promise<{ removed: number }> {
    const expired = await this.media.findExpiredPending(limit);
    const failed = await this.media.findFailed(limit);
    let removed = 0;

    for (const asset of [...expired, ...failed]) {
      if (asset.upload_expires_at && asset.upload_expires_at.getTime() > Date.now()) continue;
      try {
        await this.storageFor(asset).delete(asset.object_key);
      } catch (error) {
        logger.warn({ errorCode: errorCode(error) }, "Media object cleanup failed");
        continue;
      }
      try {
        await this.media.delete(asset.id);
        removed += 1;
      } catch (error) {
        logger.warn({ errorCode: errorCode(error) }, "Media metadata cleanup failed");
      }
    }
    return { removed };
  }

  async purgeObject(asset: Pick<MediaAsset, "purpose" | "visibility" | "object_key" | "bucket">): Promise<void> {
    await this.storageFor(asset).delete(asset.object_key);
  }

  private buildObjectKey(purpose: MediaPurpose, mimeType: string): string {
    const now = new Date();
    const month = `${now.getUTCFullYear()}-${String(now.getUTCMonth() + 1).padStart(2, "0")}`;
    const uuid = crypto.randomUUID();
    return `${PURPOSE_KEY_PREFIX[purpose]}/${month}/${uuid}.${extensionFor(mimeType)}`;
  }

  private async getOwnedAssetOrNotFound(uid: string, mediaId: string): Promise<MediaAsset> {
    const asset = await this.media.findById(mediaId);
    if (!asset) throw new NotFoundError("Media asset");
    if (asset.owner_id !== uid) {
      // Do not leak existence of other users' assets.
      throw new NotFoundError("Media asset");
    }
    return asset;
  }

  /**
   * Place assets are catalog content. Ownership alone is not enough: a
   * non-curator who owns a legacy place-purpose row (created before the
   * allowlist existed) must not be able to confirm or delete catalog media.
   */
  private assertCatalogWriteAccess(asset: MediaAsset, uid: string): void {
    if (asset.purpose === "place" && !isPlaceCurator(uid)) {
      throw new ForbiddenError("Place media requires a curator account");
    }
  }
}
