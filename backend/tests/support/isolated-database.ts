// Import before any application module in suites that instantiate Prisma.
const target = process.env.YALLA_TEST_DATABASE_URL;
export const isolatedDatabase = Boolean(target);

if (target) {
  const url = new URL(target);
  if (!["postgres:", "postgresql:"].includes(url.protocol) ||
      !["127.0.0.1", "localhost", "[::1]"].includes(url.hostname) ||
      !/^\/yalla_test[a-z0-9_]*$/.test(url.pathname) ||
      url.searchParams.has("host")) {
    throw new Error("YALLA_TEST_DATABASE_URL must point to a disposable loopback PostgreSQL database named yalla_test*");
  }
  process.env.DATABASE_URL = target;
  process.env.DIRECT_URL = target;
} else {
  // Prisma may otherwise discover backend/.env when its first operation runs.
  process.env.DATABASE_URL = "postgresql://no_database@127.0.0.1:1/yalla_test?sslmode=disable";
  process.env.DIRECT_URL = process.env.DATABASE_URL;
}
process.env.NODE_ENV = "test";
