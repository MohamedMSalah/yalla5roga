import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { parseEnv } from "node:util";

export const root = new URL("../", import.meta.url);
const modes = new Set(["device", "production"]);

export function readEnvironment(mode, { optional = false, directory = root } = {}) {
  if (!modes.has(mode)) throw new Error("Select device or production.");
  const source = new URL(`.env.${mode}`, directory);
  try {
    return parseEnv(readFileSync(source, "utf8"));
  } catch (error) {
    if (optional && error.code === "ENOENT") return {};
    throw new Error(`Cannot read .env.${mode} (${error.code === "ENOENT" ? "missing file" : "read or parse error"}).`);
  }
}

function databaseTarget(value) {
  const url = URL.parse(value ?? "");
  return url && /^(postgres|postgresql):$/.test(url.protocol) &&
    ![...url.searchParams.keys()].some(key => key.toLowerCase() === "host" || key.toLowerCase() === "hostaddr")
    ? `${url.hostname.toLowerCase().replace(/-pooler(?=\.)/, "")}${url.pathname}` : undefined;
}

export function checkDeviceIsolation(device, production) {
  if (device.SHARED_PRODUCTION_SERVICES === "true") {
    for (const key of ["DATABASE_URL", "DIRECT_URL"]) {
      if (device[key] && !databaseTarget(device[key])) throw new Error(`${key} must be a PostgreSQL URL without host overrides.`);
    }
    console.warn("WARNING: Local development uses shared production services. User actions can change live data and send notifications. Automatic mutation/cleanup jobs are disabled; never run migrations, imports or cleanup automatically.");
    return;
  }
  const databases = new Set([production.DATABASE_URL, production.DIRECT_URL].map(databaseTarget).filter(Boolean));
  for (const key of ["DATABASE_URL", "DIRECT_URL"]) {
    if (!device[key]) continue;
    const target = databaseTarget(device[key]);
    if (!target) throw new Error(`${key} in .env.device must be a PostgreSQL URL without host overrides.`);
    if (databases.has(target)) {
      throw new Error(`${key} in .env.device targets the production database. Use an isolated branch or local database.`);
    }
  }
  for (const key of ["FIREBASE_PROJECT_ID", "FIREBASE_CLIENT_EMAIL", "FIREBASE_PRIVATE_KEY", "R2_ACCESS_KEY_ID", "WHATSAPP_ACCESS_TOKEN"]) {
    if (device[key] && production[key] && device[key] === production[key]) {
      throw new Error(`${key} in .env.device matches production. Use isolated credentials.`);
    }
  }
  if (device.R2_ACCOUNT_ID && device.R2_ACCOUNT_ID === production.R2_ACCOUNT_ID) {
    const productionBuckets = [production.R2_BUCKET_NAME, production.R2_PUBLIC_BUCKET_NAME].filter(Boolean);
    for (const key of ["R2_BUCKET_NAME", "R2_PUBLIC_BUCKET_NAME"]) {
      if (productionBuckets.includes(device[key])) throw new Error(`${key} in .env.device matches production.`);
    }
  }
}

export function loadEnvironment(mode, { target = process.env, directory = root } = {}) {
  const file = readEnvironment(mode, { optional: mode === "production", directory });
  if (mode === "device") {
    const production = readEnvironment("production", { optional: true, directory });
    checkDeviceIsolation(file, production);
    // Never inherit application settings injected for a different deployment.
    for (const key of new Set([...Object.keys(production), ...Object.keys(file)])) {
      if (file[key] !== undefined) target[key] = file[key];
      else delete target[key];
    }
    delete target.FIREBASE_AUTH_EMULATOR_HOST;
    delete target.GOOGLE_APPLICATION_CREDENTIALS;
    delete target.GOOGLE_CLOUD_PROJECT;
  } else {
    for (const [key, value] of Object.entries(file)) target[key] ??= value;
    target.DEPLOYMENT_ENV ||= "production";
  }
  target.NODE_ENV = mode === "production" ? "production" : "development";
  target.APP_ENV = mode === "production" ? "production" : "development";
  target.YALLA_ENVIRONMENT = mode;
  return target;
}

export function rootPath(relative) {
  return fileURLToPath(new URL(relative, root));
}
