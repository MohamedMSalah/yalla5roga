import "dotenv/config";
import { PrismaClient } from "@prisma/client";

function shape(raw: string, direct: boolean) {
  const queryIndex = raw.indexOf("?");
  let base = queryIndex === -1 ? raw : raw.slice(0, queryIndex);
  if (direct) base = base.replace("-pooler", "");
  const params = new URLSearchParams(
    queryIndex === -1 ? "" : raw.slice(queryIndex + 1),
  );
  params.delete("channel_binding");
  if (!direct && base.includes("-pooler")) params.set("pgbouncer", "true");
  else params.delete("pgbouncer");
  if (!params.has("sslmode")) params.set("sslmode", "require");
  return `${base}?${params.toString()}`;
}

async function probe(label: string, url: string) {
  const client = new PrismaClient({
    datasources: { db: { url } },
    log: ["error"],
  });
  try {
    await client.$connect();
    await new Promise((resolve) => setTimeout(resolve, 8000));
    await client.$queryRaw`SELECT 1`;
    console.log(label, "query-ok");
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    console.log(label, "fail", message.split("\n")[0]);
  } finally {
    await client.$disconnect();
  }
}

const raw = process.env.DATABASE_URL ?? "";
const pooled = shape(raw, false);
const limited = `${pooled}&connection_limit=1`;
await probe("pooler-default", pooled);
await probe("pooler-limit-1", limited);
