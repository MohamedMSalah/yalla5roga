const configuredOrigins = (process.env.CORS_ORIGINS ?? "")
  .split(",")
  .map((origin) => origin.trim())
  .filter(Boolean);

const developmentOrigins = new Set([
  "http://localhost:3000",
  "http://localhost:5173",
  "http://127.0.0.1:3000",
  "http://127.0.0.1:5173",
]);

/** Allows native clients (no Origin) and only explicitly configured browsers. */
export function isAllowedOrigin(origin: string | undefined): boolean {
  if (!origin) return true;
  if (configuredOrigins.includes(origin)) return true;
  return process.env.NODE_ENV !== "production" && developmentOrigins.has(origin);
}

export function corsOrigin(
  origin: string | undefined,
  callback: (error: Error | null, allow?: boolean) => void,
): void {
  callback(null, isAllowedOrigin(origin));
}
