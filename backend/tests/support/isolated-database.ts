import { readEnvironment } from "../../../scripts/environment.mjs";

// Read only the opt-in test database setting, and discard application injections
// before any import can initialize a network provider.
const device = readEnvironment("device", { optional: true });
const production = readEnvironment("production", { optional: true });
const target = process.env.YALLA_TEST_DATABASE_URL ?? device.YALLA_TEST_DATABASE_URL;
for (const key of new Set([...Object.keys(device), ...Object.keys(production), ...Object.keys(process.env)])) {
  if (/^(DATABASE_URL|DIRECT_URL|FIREBASE_|GOOGLE_APPLICATION_CREDENTIALS|R2_|WHATSAPP_|GEOCODING_|EXPECTED_|MONITORING_TOKEN|PLACES_CURATOR_UIDS)/.test(key)) {
    delete process.env[key];
  }
}
export const isolatedDatabase = Boolean(target);

if (target) {
  const url = new URL(target);
  if (!["postgres:", "postgresql:"].includes(url.protocol) ||
      !["127.0.0.1", "localhost", "[::1]"].includes(url.hostname) ||
      !/^\/yalla_test[a-z0-9_]*$/.test(url.pathname) ||
      [...url.searchParams.keys()].some(key => !["sslmode", "connection_limit", "pool_timeout", "connect_timeout"].includes(key))) {
    throw new Error("YALLA_TEST_DATABASE_URL must point to a disposable loopback PostgreSQL database named yalla_test*");
  }
  process.env.DATABASE_URL = target;
  process.env.DIRECT_URL = target;
} else {
  // Any accidental query fails on loopback and cannot reach a hosted target.
  process.env.DATABASE_URL = "postgresql://no_database@127.0.0.1:1/yalla_test?sslmode=disable";
  process.env.DIRECT_URL = process.env.DATABASE_URL;
}
process.env.NODE_ENV = "test";
