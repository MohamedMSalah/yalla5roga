import { getMediaConfig, type MediaConfig } from "../../config/media.js";
import type { MediaAsset, MediaPurpose, MediaDeliveryUrl } from "../../types/media/media.types.js";
import { ConflictError, ForbiddenError, NotFoundError, ValidationError } from "../../utils/errors.js";
import type { IMediaRepository } from "../../repositories/media/i-media.repository.js";
import { MediaRepository } from "../../repositories/media/media.repository.js";
import { isPlaceCurator } from "../auth/place-curator.js";
import { MockStorageAdapter } from "./mock-storage.adapter.js";
import { R2StorageAdapter } from "./r2-storage.adapter.js";
import type { MediaStorageAdapter } from "./storage-adapter.js";
import { assertCanUploadPurpose, assertCanViewMedia } from "./media-access.js";

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
 * (`MediaStorageAdapter`); binaries never pass through this process in R2
 * mode and never touch PostgreSQL.
 */
export class MediaService {
  constructor(
    private readonly media: IMediaRepository = new MediaRepository(),
    private readonly config: MediaConfig = getMediaConfig(),
    private readonly adapterOverride?: MediaStorageAdapter,
  ) {}

  private adapter?: MediaStorageAdapter;

  storage(): MediaStorageAdapter {
    if (this.adapterOverride) return this.adapterOverride;
    if (!this.adapter) {
      if (this.config.provider === "r2") {
        this.adapter = new R2StorageAdapter();
      } else {
        this.adapter = new MockStorageAdapter(this.config.mockBaseUrl);
      }
    }
    return this.adapter;
  }

  /** Public delivery URL for public objects (Cloudflare CDN custom domain). */
  publicUrl(objectKey: string): string {
    return `${this.config.publicBaseUrl}/${objectKey}`;
  }

  /**
   * Reference stored in entity image columns: the CDN URL when real R2 +
   * CDN are configured, otherwise the stable `media://` reference so mock
   * mode still resolves through the backend.
   */
  storageReferenceFor(asset: MediaAsset): string {
    if (
      asset.visibility === "public" &&
      this.config.provider === "r2" &&
      this.config.publicBaseUrlConfigured
    ) {
      return this.publicUrl(asset.object_key);
    }
    return buildMediaReference(asset.id);
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

    if (!this.config.allowedMimeTypes.includes(input.mimeType)) {
      throw new ValidationError(`Unsupported media type ${input.mimeType}`);
    }
    if (!Number.isFinite(input.fileSize) || input.fileSize <= 0) {
      throw new ValidationError("fileSize must be a positive number");
    }
    if (input.fileSize > this.config.maxUploadBytes) {
      throw new ValidationError(
        `File exceeds the ${Math.floor(this.config.maxUploadBytes / (1024 * 1024))} MB upload limit`,
      );
    }

    await assertCanUploadPurpose({ purpose, entityId, uid });

    const adapter = this.storage();

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
      asset = await this.media.refreshUploadExpiry(
        existing.id,
        new Date(Date.now() + this.config.uploadUrlTtlSeconds * 1000),
      );
    } else {
      const key = this.buildObjectKey(purpose, input.mimeType);
      asset = await this.media.create({
        object_key: key,
        bucket: this.config.r2.bucket ?? "mock-bucket",
        mime_type: input.mimeType,
        file_size: input.fileSize,
        visibility: PURPOSE_VISIBILITY[purpose],
        owner_id: uid,
        purpose,
        upload_expires_at: new Date(Date.now() + this.config.uploadUrlTtlSeconds * 1000),
      });
    }

    const presigned = await adapter.createPresignedPutUrl({
      key: asset.object_key,
      contentType: asset.mime_type,
      contentLength: input.fileSize,
      ttlSeconds: this.config.uploadUrlTtlSeconds,
    });

    return { asset, upload_url: presigned.url, upload_expires_at: presigned.expiresAt };
  }

  /**
   * Step 2: verify the object actually landed in storage (HEAD) before the
   * asset becomes `ready`. Missing objects mark the asset `failed` so the
   * cleanup job can remove the orphan row and any partial state.
   */
  async confirmUpload(input: { uid: string; mediaId: string }): Promise<MediaAsset> {
    const asset = await this.getOwnedAssetOrNotFound(input.uid, input.mediaId);
    this.assertCatalogWriteAccess(asset, input.uid);

    if (asset.status === "ready") return asset;
    if (asset.status === "failed") {
      throw new ConflictError("Upload already failed; request a new upload URL");
    }

    const stat = await this.storage().stat(asset.object_key);
    if (!stat || stat.size <= 0) {
      await this.media.markFailed(asset.id);
      throw new ConflictError("Uploaded object was not found in storage");
    }
    return await this.media.markVerified(asset.id, stat.size, new Date());
  }

  async deleteAsset(input: { uid: string; mediaId: string }): Promise<void> {
    const asset = await this.getOwnedAssetOrNotFound(input.uid, input.mediaId);
    this.assertCatalogWriteAccess(asset, input.uid);
    try {
      await this.storage().delete(asset.object_key);
    } finally {
      await this.media.delete(asset.id);
    }
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
      } catch {
        // Skip missing/inaccessible assets instead of failing the whole batch.
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
    if (
      asset.visibility === "public" &&
      this.config.provider === "r2" &&
      this.config.publicBaseUrlConfigured
    ) {
      return {
        media_id: asset.id,
        object_key: asset.object_key,
        url: this.publicUrl(asset.object_key),
        visibility: "public",
        expires_at: null,
      };
    }
    const presigned = await this.storage().createPresignedGetUrl({
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
    if (!assetId) return raw; // Existing http(s) URLs and defaults are untouched.

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
    if (!asset || asset.owner_id !== input.uid) return;
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
      try {
        await this.storage().delete(asset.object_key);
      } catch (error) {
        console.error(`[media] failed to delete object ${asset.object_key}`, error);
      }
      try {
        await this.media.delete(asset.id);
        removed += 1;
      } catch (error) {
        console.error(`[media] failed to delete asset row ${asset.id}`, error);
      }
    }
    return { removed };
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
