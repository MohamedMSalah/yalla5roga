/**
 * Storage-agnostic contract for the media service. Two implementations exist:
 *
 * - `MockStorageAdapter` — in-process store backed by local dev routes;
 *   used whenever R2 credentials are not configured.
 * - `R2StorageAdapter` — real Cloudflare R2 through the S3-compatible API.
 */

export type StoredObject = {
  key: string;
  size: number;
  contentType: string | null;
  lastModified: Date | null;
  etag: string | null;
};

export type PresignedPut = {
  url: string;
  /** Absolute time when the URL stops working. */
  expiresAt: Date;
  key: string;
};

export type PresignedGet = {
  url: string;
  expiresAt: Date;
  key: string;
};

export interface MediaStorageAdapter {
  /** Human-readable provider name for logs and health endpoints. */
  readonly name: string;
  /** Presign a direct PUT for the client. Must not require backend bandwidth. */
  createPresignedPutUrl(input: {
    key: string;
    contentType: string;
    contentLength?: number;
    ttlSeconds: number;
  }): Promise<PresignedPut>;
  /** Presign a short-lived GET for a private object. */
  createPresignedGetUrl(input: {
    key: string;
    ttlSeconds: number;
  }): Promise<PresignedGet>;
  /** Head the object; `null` means it does not exist (upload failed/aborted). */
  stat(key: string): Promise<StoredObject | null>;
  /** Permanently delete the object. Deleting a missing key is not an error. */
  delete(key: string): Promise<void>;
}
