import type { Prisma } from "@prisma/client";
import { setDependency } from "../../monitoring/health.js";
import { logger } from "../../monitoring/logger.js";
import { Client } from "pg";
import { getChatIo } from "../../realtime/chat-emitter.js";

/** PostgreSQL delivers this only after the enclosing catalog transaction commits. */
export async function notifyCatalogChanged(tx: Prisma.TransactionClient) {
  await tx.$executeRaw`SELECT pg_notify('places_catalog_changed','changed')`;
}

/** Dedicated direct session: PgBouncer transaction pooling cannot hold LISTEN. */
export function startCatalogListener() {
  setDependency("catalog_listener", "pending");
  let stopped = false,
    client: Client | undefined,
    timer: ReturnType<typeof setTimeout> | undefined,
    attempt = 0;
  const reconnect = () => {
    if (stopped || timer) return;
    timer = setTimeout(
      () => {
        timer = undefined;
        void connect();
      },
      Math.min(60000, 1000 * 2 ** Math.min(attempt++, 6)),
    );
    timer.unref();
  };
  async function connect() {
    const url = new URL(process.env.DATABASE_URL!);
    url.hostname = url.hostname.replace("-pooler.", ".");
    for (const key of [
      "schema",
      "connection_limit",
      "pool_timeout",
      "channel_binding",
      "pgbouncer",
    ])
      url.searchParams.delete(key);
    if (url.hostname.endsWith(".neon.tech"))
      url.searchParams.set("sslmode", "verify-full");
    const session = new Client({
      connectionString: url.toString(),
      application_name: "yalla5roga-catalog-listener",
      connectionTimeoutMillis: 15000,
    });
    client = session;
    const disconnected = () => {
      if (client === session) {
        client = undefined;
        if (!stopped) setDependency("catalog_listener", "degraded");
        void session.end().catch(() => {});
        reconnect();
      }
    };
    session.on("error", disconnected);
    session.on("end", disconnected);
    session.on("notification", (message) => {
      if (message.channel === "places_catalog_changed")
        getChatIo()?.emit("catalog:changed", {});
    });
    try {
      await session.connect();
      if (stopped) {
        await session.end();
        return;
      }
      await session.query("LISTEN places_catalog_changed");
      attempt = 0;
      setDependency("catalog_listener", "ready");
      getChatIo()?.emit("catalog:changed", {});
    } catch {
      if (attempt === 0 && !stopped) logger.warn("Catalog listener unavailable; retry scheduled");
      disconnected();
    }
  }
  void connect();
  return async () => {
    stopped = true;
    setDependency("catalog_listener", "stopping");
    if (timer) clearTimeout(timer);
    await client?.end();
  };
}
