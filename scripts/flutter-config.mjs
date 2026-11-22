import { existsSync, readFileSync } from "node:fs";
import { isIP } from "node:net";
import { checkDeviceIsolation, readEnvironment, rootPath } from "./environment.mjs";

const required = [
  "APP_ENV", "API_BASE_URL", "FIREBASE_PROJECT_ID", "FIREBASE_ANDROID_API_KEY",
  "FIREBASE_ANDROID_APP_ID", "FIREBASE_IOS_API_KEY", "FIREBASE_IOS_APP_ID",
  "FIREBASE_MESSAGING_SENDER_ID", "FIREBASE_STORAGE_BUCKET", "FIREBASE_IOS_BUNDLE_ID",
  "FIREBASE_IOS_CLIENT_ID", "FIREBASE_WEB_CLIENT_ID",
];
const urls = [
  "APP_DOWNLOAD_URL", "OSM_TILE_URL", "OSM_DARK_TILE_URL", "MAP_VECTOR_TILEJSON_URL",
  "MAP_GLYPHS_URL", "MAP_ATTRIBUTION_URL", "MAP_LIGHT_STYLE_URL", "MAP_DARK_STYLE_URL",
];
export const clientKeys = new Set([
  ...required, ...urls,
  "API_CONNECT_TIMEOUT_MS", "API_RECEIVE_TIMEOUT_MS", "OSM_DARK_TILE_ATTRIBUTION",
  "MAP_ATTRIBUTION", "MAP_OFFLINE_ALLOWED", "API_DIAGNOSTICS", "API_DIAGNOSTICS_LOG",
  "API_DUPLICATE_WINDOW_MS", "API_TELEMETRY_SAMPLE", "PLACE_RECOMMENDATIONS_TTL_SECONDS",
  "IMAGE_UPLOAD_MAX_EDGE", "IMAGE_UPLOAD_TARGET_BYTES", "IMAGE_UPLOAD_QUALITY",
  "FIREBASE_TELEMETRY_ENABLED",
]);

export function clientValues(mode, env) {
  if (mode !== "device" && mode !== "production") throw new Error("Select device or production.");
  const appEnv = mode === "production" ? "production" : "development";
  if (env.APP_ENV !== appEnv) throw new Error(`Set APP_ENV=${appEnv} in .env.${mode}.`);
  const missing = required.filter(key => !env[key]?.trim());
  if (missing.length) throw new Error(`Missing client settings: ${missing.join(", ")}.`);
  const api = URL.parse(env.API_BASE_URL);
  if (!api || !["http:", "https:"].includes(api.protocol) || api.username || api.password ||
    api.pathname !== "/" || api.search || api.hash ||
    (mode === "production" && (api.protocol !== "https:" || isIP(api.hostname.replace(/^\[|\]$/g, "")) ||
      !api.hostname.includes(".") || /\.(localhost|local|internal)$/.test(api.hostname)))) {
    throw new Error("Set API_BASE_URL to a bare API origin (public HTTPS DNS origin for production).");
  }
  if (mode === "device" && (api.protocol !== "http:" || api.port !== "3000" ||
    !/^(10\.|192\.168\.|172\.(1[6-9]|2\d|3[01])\.)/.test(api.hostname) || isIP(api.hostname) !== 4)) {
    throw new Error("Device API_BASE_URL must use an HTTP private LAN IPv4 address on port 3000.");
  }
  for (const key of urls) {
    if (!env[key]) continue;
    const url = URL.parse(env[key]);
    if (url?.protocol !== "https:" || url.username || url.password) {
      throw new Error(`${key} must be a public HTTPS URL without user credentials.`);
    }
  }
  return Object.fromEntries([...clientKeys].filter(key => env[key]?.trim()).map(key => {
    const value = env[key].trim();
    if (/\r|\n|-----BEGIN |(?:postgres(?:ql)?):\/\//i.test(value)) {
      throw new Error(`${key} contains an invalid client value.`);
    }
    return [key, value];
  }));
}

// Compatibility for configuration consumers; builds use the sanitized JSON file.
export function clientArguments(mode, env) {
  return Object.entries(clientValues(mode, env)).map(([key, value]) => `--dart-define=${key}=${value}`);
}

export function readClientBuild(mode) {
  const env = readEnvironment(mode);
  const other = readEnvironment(mode === "device" ? "production" : "device", { optional: true });
  const values = clientValues(mode, env);
  if (mode === "device") checkDeviceIsolation(env, other);
  // Explicit Dart options and Android resources must identify the same app.
  const base = "flutter/android/app/";
  const variant = rootPath(`${base}src/${mode}/google-services.json`);
  const native = existsSync(variant) ? variant : rootPath(`${base}google-services.json`);
  let config;
  try { config = JSON.parse(readFileSync(native, "utf8")); }
  catch { throw new Error("Install google-services.json for the selected Android variant."); }
  if (config.project_info?.project_id !== env.FIREBASE_PROJECT_ID ||
    String(config.project_info?.project_number) !== env.FIREBASE_MESSAGING_SENDER_ID ||
    !config.client?.some(client => client.client_info?.mobilesdk_app_id === env.FIREBASE_ANDROID_APP_ID &&
      client.client_info?.android_client_info?.package_name === "com.example.yalla_5roga" &&
      client.api_key?.some(key => key.current_key === env.FIREBASE_ANDROID_API_KEY))) {
    throw new Error("Android google-services.json does not match the selected Firebase project, app ID and client key.");
  }
  return { values, excluded: Object.keys({ ...other, ...env }) };
}
