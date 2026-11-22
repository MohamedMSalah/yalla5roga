import type {
  MediaStorageAdapter,
  PresignedGet,
  PresignedPut,
  StoredObject,
} from "./storage-adapter.js";

/**
 * In-process development adapter. Real uploads flow through backend-local
 * `PUT /api/media/mock-upload/{key}` routes so the whole direct-upload flow
 * (presign → client PUT → confirm) is exercised without Cloudflare
 * credentials. Objects live in memory only and are lost on restart; never
 * enabled when R2 credentials are configured.
 */
export class MockStorageAdapter implements MediaStorageAdapter {
  readonly name = "mock";

  private readonly objects = new Map<
    string,
    { bytes: Uint8Array; contentType: string | null; lastModified: Date }
  >();
  private readonly issuedKeys = new Map<string, { expiresAt: number; length?: number; type: string }>();

  constructor(
    private readonly baseUrl: string,
    /** Total in-memory byte budget for local development. */
    private readonly maxTotalBytes = 64 * 1024 * 1024,
  ) {}

  private static usedBytes(
    objects: MockStorageAdapter["objects"],
  ): number {
    let total = 0;
    for (const entry of objects.values()) total += entry.bytes.byteLength;
    return total;
  }

  async createPresignedPutUrl(input: {
    key: string;
    contentType: string;
    contentLength?: number;
    ttlSeconds: number;
  }): Promise<PresignedPut> {
    const expiresAt = new Date(Date.now() + input.ttlSeconds * 1000);
    this.issuedKeys.set(input.key, { expiresAt: expiresAt.getTime(), length: input.contentLength, type: input.contentType });
    return {
      url: `${this.baseUrl}/api/media/mock-upload/${encodeURIComponent(input.key)}`,
      expiresAt,
      key: input.key,
    };
  }

  async createPresignedGetUrl(input: {
    key: string;
    ttlSeconds: number;
  }): Promise<PresignedGet> {
    const expiresAt = new Date(Date.now() + input.ttlSeconds * 1000);
    return {
      url: `${this.baseUrl}/api/media/mock-download/${encodeURIComponent(input.key)}`,
      expiresAt,
      key: input.key,
    };
  }

  /** Mock upload route entry point: stores the bytes locally. */
  store(key: string, bytes: Uint8Array, contentType: string | null): void {
    const intent = this.issuedKeys.get(key);
    if (!intent || intent.expiresAt <= Date.now() || intent.type !== contentType ||
      (intent.length !== undefined && intent.length !== bytes.byteLength)) {
      throw new Error("Invalid or expired mock upload");
    }
    this.save(key, bytes, contentType);
  }

  private save(key: string, bytes: Uint8Array, contentType: string | null): void {
    const previous = this.objects.get(key)?.bytes.byteLength ?? 0;
    if (MockStorageAdapter.usedBytes(this.objects) - previous + bytes.byteLength > this.maxTotalBytes) {
      throw new Error("Mock object exceeds the local byte budget");
    }
    this.objects.set(key, {
      bytes,
      contentType,
      lastModified: new Date(),
    });
  }

  async read(key: string, maxBytes: number): Promise<Buffer | null> {
    const object = this.objects.get(key);
    return object && object.bytes.length <= maxBytes ? Buffer.from(object.bytes) : null;
  }

  async write(key: string, bytes: Buffer, mimeType: string): Promise<void> {
    this.save(key, bytes, mimeType);
  }

  /** Mock download route entry point. */
  load(key: string): { bytes: Uint8Array; contentType: string | null } | null {
    if (key.startsWith("uploads/")) return null;
    const entry = this.objects.get(key);
    if (!entry) return null;
    return { bytes: entry.bytes, contentType: entry.contentType };
  }

  async stat(key: string): Promise<StoredObject | null> {
    const entry = this.objects.get(key);
    if (!entry) return null;
    return {
      key,
      size: entry.bytes.byteLength,
      contentType: entry.contentType,
      lastModified: entry.lastModified,
      etag: null,
    };
  }

  async delete(key: string): Promise<void> {
    this.objects.delete(key);
    this.issuedKeys.delete(key);
  }
}

// Keep one instance across HMR/module reloads in watch mode.
const globalForMock = globalThis as unknown as {
  __mediaMockAdapter?: MockStorageAdapter;
};

export function getMockStorageAdapter(baseUrl: string): MockStorageAdapter {
  globalForMock.__mediaMockAdapter ??= new MockStorageAdapter(baseUrl);
  return globalForMock.__mediaMockAdapter;
}
