import { PrismaClient } from "@prisma/client";
import { enabled } from "../monitoring/config.js";
import { observe } from "../monitoring/metrics.js";
import { instrumentPrisma } from "../monitoring/prisma.js";

const globalForPrisma = globalThis as unknown as {
  prisma?: PrismaClient;
};

/**
 * Neon dashboard strings include `channel_binding=require`. Prisma's query
 * engine does not implement SCRAM channel binding, and Neon then closes the
 * socket.
 * The `-pooler` host is PgBouncer. It closes idle server connections, which
 * Prisma reports as `Error { kind: Closed, cause: None }`. This process is a
 * long-running server, so it uses the direct host instead.
 */
function connectionString(raw: string | undefined): string | undefined {
  if (!raw) return raw;

  const queryIndex = raw.indexOf("?");
  let base = queryIndex === -1 ? raw : raw.slice(0, queryIndex);
  const params = new URLSearchParams(
    queryIndex === -1 ? "" : raw.slice(queryIndex + 1),
  );

  params.delete("channel_binding");
  params.delete("pgbouncer");
  base = base.replace(/@([^/@?]+)-pooler(\.)/, "@$1$2");

  if (!params.has("sslmode")) {
    params.set("sslmode", "require");
  }
  if (!params.has("connection_limit")) params.set("connection_limit", "5");
  if (!params.has("connect_timeout")) params.set("connect_timeout", "10");
  if (!params.has("pool_timeout")) params.set("pool_timeout", "10");

  const query = params.toString();
  return query.length > 0 ? `${base}?${query}` : base;
}

const url = connectionString(process.env.DATABASE_URL);

function createClient() {
  const client = new PrismaClient({
    datasources: url ? { db: { url } } : undefined,
    // Row-locked workflows can queue behind a concurrent request over Neon.
    transactionOptions: { maxWait: 10_000, timeout: 15_000 },
    log: enabled ? [{ emit: "event", level: "query" } as const] : [],
  });
  if (enabled) {
    client.$on("query", event => observe("db_engine_query_seconds", event.duration / 1000));
  }
  return instrumentPrisma(client);
}

export const prisma = globalForPrisma.prisma ?? createClient();

if (process.env.NODE_ENV !== "production") {
  globalForPrisma.prisma = prisma;

}

export default prisma;
