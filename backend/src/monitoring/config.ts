export const environment = process.env.NODE_ENV === "production" ? "production"
  : process.env.NODE_ENV === "test" ? "test" : "development";
export const enabled = process.env.OBSERVABILITY_ENABLED !== "0";
export const isolatedTestTarget = (() => {
  if (environment === "production" || process.env.OBS_ISOLATED_LOAD_TEST !== "1") return false;
  try {
    const url = new URL(process.env.DATABASE_URL ?? "");
    return ["postgres:", "postgresql:"].includes(url.protocol) &&
      ["127.0.0.1", "localhost", "[::1]"].includes(url.hostname) &&
      /^\/yalla_test[a-z0-9_]*$/.test(url.pathname) && !url.searchParams.has("host");
  } catch { return false; }
})();

function numberSetting(name: string, fallback: number, min: number, max: number) {
  const raw = process.env[name];
  const value = raw?.trim() ? Number(raw) : NaN;
  return Number.isFinite(value) && value >= min && value <= max ? value : fallback;
}

export const requestLogSample = numberSetting("OBS_HTTP_LOG_SAMPLE", environment === "production" ? 0 : 1, 0, 1);
export const duplicateWindowMs = numberSetting("OBS_DUPLICATE_WINDOW_MS", 2000, 100, 60000);
export const healthTtlMs = numberSetting("OBS_HEALTH_TTL_MS", 15000, 1000, 120000);
export const queryWarningMs = numberSetting("OBS_DB_WARN_MS", 100, 1, 60000);
export const queryCriticalMs = Math.max(queryWarningMs, numberSetting("OBS_DB_CRITICAL_MS", 500, 1, 120000));

type Threshold = { good: number; warning: number; critical: number };
const defaults = { good: 250, warning: 500, critical: 1000 };
const overrides = new Map<string, Threshold>();
try {
  const settings = JSON.parse(process.env.OBS_ENDPOINT_THRESHOLDS ?? "{}");
  for (const [key, value] of Object.entries(settings).slice(0, 200)) {
    const { good, warning, critical } = value as Threshold;
    if (Number.isFinite(good) && good > 0 && good <= warning && warning <= critical && critical <= 120000) {
      overrides.set(key, { good, warning, critical });
    }
  }
} catch { /* Optional monitoring settings fall back to defaults. */ }

export function latencyBand(method: string, route: string, ms: number) {
  const { good, warning, critical } = overrides.get(`${method} ${route}`) ?? defaults;
  return ms >= critical ? "critical" : ms >= warning ? "warning" : ms < good ? "good" : "elevated";
}

export const triggers = new Set([
  "initial_load", "manual_refresh", "navigation", "app_resume", "socket_event",
  "cache_expired", "pagination", "viewport_changed", "search", "retry", "background_sync",
]);
