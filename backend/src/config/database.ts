import { PrismaClient } from "@prisma/client";

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

  const query = params.toString();
  return query.length > 0 ? `${base}?${query}` : base;
}

const url = connectionString(process.env.DATABASE_URL);

export const prisma =
  globalForPrisma.prisma ??
  new PrismaClient({
    datasources: url ? { db: { url } } : undefined,
    log:
      process.env.NODE_ENV === "development"
        ? ["query", "error", "warn"]
        : ["error"],
  });

if (process.env.NODE_ENV !== "production") {
  globalForPrisma.prisma = prisma;

  // Neon suspends an idle compute and drops open sockets. A quiet ping keeps
  // the dev connection alive so the next request does not hit a closed socket.
  const timer = setInterval(() => {
    prisma.$queryRaw`SELECT 1`.catch(() => undefined);
  }, 4 * 60 * 1000);
  timer.unref();
}

export default prisma;
