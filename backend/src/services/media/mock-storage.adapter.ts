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
  private readonly issuedKeys = new Set<string>();

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
    this.issuedKeys.add(input.key);
    const expiresAt = new Date(Date.now() + input.ttlSeconds * 1000);
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
    if (!this.issuedKeys.has(key)) {
      throw new Error(`Object key ${key} was never issued for upload`);
    }
    if (bytes.byteLength > this.maxTotalBytes) {
      throw new Error("Mock object exceeds the local byte budget");
    }
    this.objects.set(key, {
      bytes,
      contentType,
      lastModified: new Date(),
    });
  }

  /** Mock download route entry point. */
  load(key: string): { bytes: Uint8Array; contentType: string | null } | null {
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
