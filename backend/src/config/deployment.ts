import { isIP } from "node:net";
import { getMediaConfig } from "./media.js";

export function trustedProxyAddresses(raw = process.env.TRUST_PROXY): string[] {
  if (!raw?.trim()) return [];
  return raw.split(",").map(part => {
    const value = part.trim();
    const [address, prefix, ...extra] = value.split("/");
    const version = isIP(address ?? "");
    if (!version || extra.length || (prefix !== undefined &&
      (!/^\d{1,3}$/.test(prefix) || Number(prefix) < 1 || Number(prefix) > (version === 4 ? 32 : 128)))) {
      throw new Error("TRUST_PROXY must list specific ingress IP addresses or CIDRs");
    }
    return value;
  });
}

export function validateProductionConfig(env: NodeJS.ProcessEnv = process.env): void {
  if (env.DEPLOYMENT_ENV !== "staging" && env.DEPLOYMENT_ENV !== "production") {
    throw new Error("DEPLOYMENT_ENV");
  }
  if (env.FIREBASE_AUTH_EMULATOR_HOST || env.GOOGLE_CLOUD_PROJECT && env.GOOGLE_CLOUD_PROJECT !== env.FIREBASE_PROJECT_ID) {
    throw new Error("FIREBASE_PROJECT_ID");
  }
  if (!env.FIREBASE_PROJECT_ID || env.FIREBASE_PROJECT_ID !== env.EXPECTED_FIREBASE_PROJECT_ID) {
    throw new Error("FIREBASE_PROJECT_ID");
  }
  if (!env.FIREBASE_API_KEY?.trim()) throw new Error("FIREBASE_API_KEY");
  if (!env.FIREBASE_CLIENT_EMAIL?.endsWith(`@${env.FIREBASE_PROJECT_ID}.iam.gserviceaccount.com`)) {
    throw new Error("FIREBASE_CLIENT_EMAIL");
  }
  if (!env.FIREBASE_PRIVATE_KEY?.trim()) throw new Error("FIREBASE_PRIVATE_KEY");
  if (env.API_BASE_URL?.trim()) {
    const url = URL.parse(env.API_BASE_URL.trim());
    if (!url || url.protocol !== "https:" || url.username || url.password ||
      url.pathname !== "/" || url.search || url.hash) throw new Error("API_BASE_URL");
  }
  const origins = env.CORS_ORIGINS?.split(",").map(value => value.trim());
  if (!origins?.length || origins.some(value => {
    try { const url = new URL(value); return url.protocol !== "https:" || url.origin !== value; }
    catch { return true; }
  })) throw new Error("CORS_ORIGINS");
  trustedProxyAddresses(env.TRUST_PROXY ?? "");
  if (env.WHATSAPP_PROVIDER === "stub") throw new Error("WHATSAPP_PROVIDER");

  validateDatabaseTargets(env);

  for (const key of ["R2_ACCOUNT_ID", "R2_ACCESS_KEY_ID", "R2_SECRET_ACCESS_KEY", "R2_BUCKET_NAME",
    "EXPECTED_R2_ACCOUNT_ID", "EXPECTED_R2_PRIVATE_BUCKET"]) {
    if (!env[key]?.trim()) throw new Error(key);
  }
  const media = getMediaConfig(env);
  if (media.provider !== "r2" || media.r2.accountId !== env.EXPECTED_R2_ACCOUNT_ID ||
    media.r2.bucket !== env.EXPECTED_R2_PRIVATE_BUCKET ||
    (media.r2.publicBucket ?? undefined) !== (env.EXPECTED_R2_PUBLIC_BUCKET?.trim() || undefined)) {
    throw new Error("R2_BUCKET_NAME");
  }
  const r2 = URL.parse(media.r2.endpoint ?? "");
  const r2Host = media.r2.accountId;
  if (!r2 || r2.protocol !== "https:" || r2.origin !== `https://${r2.hostname}` || r2.pathname !== "/" ||
    r2.search || r2.hash || r2.username || r2.password ||
    ![r2Host, `${r2Host}.eu`, `${r2Host}.fedramp`].some(host => r2.hostname === `${host}.r2.cloudflarestorage.com`)) {
    throw new Error("R2_ENDPOINT");
  }
}

export function validateDatabaseTargets(env: NodeJS.ProcessEnv): void {
  for (const key of ["DATABASE_URL", "DIRECT_URL"] as const) {
    const value = env[key];
    if (key === "DIRECT_URL" && !value) continue;
    try {
      const url = new URL(value ?? "");
      const hostname = url.hostname.replace(/-pooler(?=\.)/, "");
      const local = hostname === "127.0.0.1" || hostname === "[::1]";
      if (!["postgres:", "postgresql:"].includes(url.protocol) ||
        hostname !== env.EXPECTED_DATABASE_HOST ||
        url.pathname !== `/${env.EXPECTED_DATABASE_NAME}` ||
        [...url.searchParams.keys()].some(key => ["host", "hostaddr"].includes(key.toLowerCase())) ||
        (local ? env.DEPLOYMENT_ENV !== "staging" || !/^\/yalla_test[a-z0-9_]*$/.test(url.pathname)
          : !["require", "verify-ca", "verify-full"].includes(url.searchParams.get("sslmode") ?? ""))) {
        throw new Error(key);
      }
    } catch {
      throw new Error(key);
    }
  }
}
