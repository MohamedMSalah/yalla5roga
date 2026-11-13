import {
  DeleteObjectCommand,
  GetObjectCommand,
  HeadObjectCommand,
  PutObjectCommand,
  S3Client,
} from "@aws-sdk/client-s3";
import { getSignedUrl } from "@aws-sdk/s3-request-presigner";
import { getMediaConfig } from "../../config/media.js";
import type {
  MediaStorageAdapter,
  PresignedGet,
  PresignedPut,
  StoredObject,
} from "./storage-adapter.js";

/**
 * Real Cloudflare R2 adapter using the S3-compatible API.
 *
 * Constructed only when the media config resolves `provider = "r2"` (all
 * credentials present). Presigned PUT/GET URLs are signed by this process;
 * the client then talks to R2 directly so binaries never pass through the
 * backend or Neon.
 */
export class R2StorageAdapter implements MediaStorageAdapter {
  readonly name = "r2";

  private readonly client: S3Client;
  private readonly bucket: string;

  constructor(
    options: {
      accountId: string;
      accessKeyId: string;
      secretAccessKey: string;
      bucket: string;
      endpoint?: string | null;
    } = (() => {
      const config = getMediaConfig();
      if (!config.r2.accountId || !config.r2.accessKeyId || !config.r2.secretAccessKey || !config.r2.bucket) {
        throw new Error(
          "R2StorageAdapter requires R2_ACCOUNT_ID, R2_ACCESS_KEY_ID, R2_SECRET_ACCESS_KEY and R2_BUCKET_NAME",
        );
      }
      return {
        accountId: config.r2.accountId,
        accessKeyId: config.r2.accessKeyId,
        secretAccessKey: config.r2.secretAccessKey,
        bucket: config.r2.bucket,
        endpoint: config.r2.endpoint,
      };
    })(),
  ) {
    this.bucket = options.bucket;
    this.client = new S3Client({
      region: "auto",
      endpoint: options.endpoint ?? `https://${options.accountId}.r2.cloudflarestorage.com`,
      credentials: {
        accessKeyId: options.accessKeyId,
        secretAccessKey: options.secretAccessKey,
      },
    });
  }

  async createPresignedPutUrl(input: {
    key: string;
    contentType: string;
    contentLength?: number;
    ttlSeconds: number;
  }): Promise<PresignedPut> {
    const command = new PutObjectCommand({
      Bucket: this.bucket,
      Key: input.key,
      ContentType: input.contentType,
      ...(input.contentLength ? { ContentLength: input.contentLength } : {}),
    });
    const expiresAt = new Date(Date.now() + input.ttlSeconds * 1000);
    const url = await getSignedUrl(this.client, command, {
      expiresIn: input.ttlSeconds,
    });
    return { url, expiresAt, key: input.key };
  }

  async createPresignedGetUrl(input: {
    key: string;
    ttlSeconds: number;
  }): Promise<PresignedGet> {
    const command = new GetObjectCommand({
      Bucket: this.bucket,
      Key: input.key,
    });
    const expiresAt = new Date(Date.now() + input.ttlSeconds * 1000);
    const url = await getSignedUrl(this.client, command, {
      expiresIn: input.ttlSeconds,
    });
    return { url, expiresAt, key: input.key };
  }

  async stat(key: string): Promise<StoredObject | null> {
    try {
      const head = await this.client.send(
        new HeadObjectCommand({ Bucket: this.bucket, Key: key }),
      );
      return {
        key,
        size: head.ContentLength ?? 0,
        contentType: head.ContentType ?? null,
        lastModified: head.LastModified ?? null,
        etag: head.ETag ?? null,
      };
    } catch (error) {
      const name = (error as { name?: string }).name;
      // SDK distinguishes 404 (NotFound / 404) from transport failures.
      if (name === "NotFound" || name === "NoSuchKey") return null;
      throw error;
    }
  }

  async delete(key: string): Promise<void> {
    await this.client.send(
      new DeleteObjectCommand({ Bucket: this.bucket, Key: key }),
    );
  }
}
