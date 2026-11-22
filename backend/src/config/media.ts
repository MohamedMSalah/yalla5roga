/**
 * Media storage configuration (Cloudflare R2 via S3-compatible API).
 *
 * Credentials are provided later. Until every required R2 variable is set the
 * media service runs on the configurable in-process mock adapter, so local
 * development and tests work without real object storage. Switching to real
 * R2 is purely an environment change — no code edits.
 */

export type MediaStorageProvider = "mock" | "r2";

export type MediaConfig = {
  /** Resolved provider: `r2` only when all R2 credentials are present. */
  provider: MediaStorageProvider;
  r2: {
    accountId: string | null;
    accessKeyId: string | null;
    secretAccessKey: string | null;
    bucket: string | null;
    /** Separate bucket containing only public catalog images. */
    publicBucket?: string | null;
    /** S3 endpoint; defaults to `https://<accountId>.r2.cloudflarestorage.com`. */
    endpoint: string | null;
    /** Optional R2 jurisdiction subdomain hint, e.g. "eu". */
    jurisdiction: string | null;
  };
  /** Public CDN base for `public` visibility assets. Placeholder until configured. */
  publicBaseUrl: string;
  /** True once publicBaseUrl differs from the placeholder domain. */
  publicBaseUrlConfigured: boolean;
  /** Presigned PUT / GET lifetime. */
  uploadUrlTtlSeconds: number;
  signedGetUrlTtlSeconds: number;
  /** Maximum accepted upload size in bytes. */
  maxUploadBytes: number;
  cleanupIntervalMs: number;
  /** Base URL used by the mock adapter's local upload/download routes. */
  mockBaseUrl: string;
  allowedMimeTypes: string[];
};

const PLACEHOLDER_PUBLIC_BASE = "https://media.example.com";
const DEFAULT_ALLOWED_MIME_TYPES = [
  "image/jpeg",
  "image/png",
  "image/webp",
  "image/gif",
];

export function getMediaConfig(settings: NodeJS.ProcessEnv = process.env): MediaConfig {
  const env = (name: string) => settings[name]?.trim() || null;
  const envInt = (name: string, fallback: number) => {
    const value = Number(env(name));
    return Number.isSafeInteger(value) && value > 0 ? value : fallback;
  };
  const accountId = env("R2_ACCOUNT_ID");
  const accessKeyId = env("R2_ACCESS_KEY_ID");
  const secretAccessKey = env("R2_SECRET_ACCESS_KEY");
  const bucket = env("R2_BUCKET_NAME");
  const endpoint = env("R2_ENDPOINT");
  const jurisdiction = env("R2_JURISDICTION");
  const publicBucket = env("R2_PUBLIC_BUCKET_NAME");

  const publicBaseUrl = (
    env("R2_PUBLIC_BASE_URL") ?? PLACEHOLDER_PUBLIC_BASE
  ).replace(/\/+$/, "");
  const publicBaseUrlConfigured = publicBaseUrl !== PLACEHOLDER_PUBLIC_BASE;
  if (publicBucket && (publicBucket === bucket || !bucket)) {
    throw new Error("R2_PUBLIC_BUCKET_NAME must be separate from R2_BUCKET_NAME");
  }
  if (publicBaseUrlConfigured) {
    const url = URL.parse(publicBaseUrl);
    if (!publicBucket || !url || url.protocol !== "https:" || url.username || url.password ||
      url.search || url.hash || url.pathname !== "/") {
      throw new Error("R2_PUBLIC_BASE_URL requires a separate public bucket and an HTTPS origin");
    }
  }

  return {
    provider: accountId && accessKeyId && secretAccessKey && bucket ? "r2" : "mock",
    r2: {
      accountId,
      accessKeyId,
      secretAccessKey,
      bucket,
      publicBucket,
      endpoint:
        endpoint ??
        (accountId ? `https://${accountId}${jurisdiction ? `.${jurisdiction}` : ""}.r2.cloudflarestorage.com` : null),
      jurisdiction,
    },
    publicBaseUrl,
    publicBaseUrlConfigured,
    uploadUrlTtlSeconds: Math.min(envInt("MEDIA_UPLOAD_URL_TTL_SECONDS", 900), 900),
    signedGetUrlTtlSeconds: Math.min(envInt("MEDIA_SIGNED_URL_TTL_SECONDS", 300), 300),
    maxUploadBytes: Math.min(envInt("MEDIA_MAX_UPLOAD_BYTES", 10 * 1024 * 1024), 10 * 1024 * 1024),
    cleanupIntervalMs: envInt("MEDIA_CLEANUP_INTERVAL_MS", 60 * 60 * 1000),
    mockBaseUrl: env("MEDIA_MOCK_BASE_URL") ?? "http://localhost:3000",
    allowedMimeTypes:
      env("MEDIA_ALLOWED_MIME_TYPES")?.split(",").map((m) => m.trim()).filter(
        Boolean,
      ) ?? DEFAULT_ALLOWED_MIME_TYPES,
  };
}

export const MEDIA_PLACEHOLDER_PUBLIC_BASE = PLACEHOLDER_PUBLIC_BASE;
