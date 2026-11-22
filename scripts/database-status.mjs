import { createHash } from "node:crypto";
import { readFileSync, readdirSync } from "node:fs";
import { createRequire } from "node:module";
import { loadEnvironment, rootPath } from "./environment.mjs";

const { Client } = createRequire(new URL("../backend/package.json", import.meta.url))("pg");
let client;
try {
  const env = loadEnvironment(process.argv[2]);
  const target = URL.parse(env.DIRECT_URL || env.DATABASE_URL || "");
  if (!target || !["postgres:", "postgresql:"].includes(target.protocol) ||
    [...target.searchParams.keys()].some(key => ["host", "hostaddr"].includes(key.toLowerCase()))) {
    throw new Error("invalid target");
  }
  if (process.argv[2] === "production") {
    const { validateDatabaseTargets } = await import("../backend/dist/config/deployment.js");
    validateDatabaseTargets(env);
  }
  for (const key of ["schema", "connection_limit", "pool_timeout", "connect_timeout", "pgbouncer"]) target.searchParams.delete(key);
  if (target.hostname.endsWith(".neon.tech")) target.searchParams.set("sslmode", "verify-full");
  client = new Client({ connectionString: target.toString(), connectionTimeoutMillis: 8000, statement_timeout: 8000 });
  await client.connect();
  await client.query("BEGIN READ ONLY");
  const { rows } = await client.query(`SELECT migration_name, checksum, finished_at IS NOT NULL AS finished,
    rolled_back_at IS NOT NULL AS rolled_back FROM _prisma_migrations ORDER BY started_at`);
  const migrations = readdirSync(rootPath("backend/prisma/migrations"), { withFileTypes: true })
    .filter(entry => entry.isDirectory()).map(entry => entry.name).sort();
  const applied = new Map(rows.filter(row => row.finished && !row.rolled_back).map(row => [row.migration_name, row.checksum]));
  const pending = migrations.filter(name => !applied.has(name));
  const unexpected = [...applied.keys()].filter(name => !migrations.includes(name));
  const changed = migrations.filter(name => {
    if (!applied.has(name)) return false;
    const sql = readFileSync(rootPath(`backend/prisma/migrations/${name}/migration.sql`), "utf8");
    const lf = sql.replace(/\r\n/g, "\n");
    return ![sql, lf, lf.replace(/\n/g, "\r\n")].some(content =>
      createHash("sha256").update(content).digest("hex") === applied.get(name));
  });
  const failed = rows.filter(row => !row.finished && !row.rolled_back).map(row => row.migration_name);
  await client.query("ROLLBACK");
  console.log(JSON.stringify({ local: migrations.length, applied: applied.size, pending, changed, unexpected, failed }, null, 2));
  if (changed.length || unexpected.length || failed.length) process.exitCode = 1;
} catch (error) {
  const code = /^[A-Z0-9_]{2,40}$/.test(error.code ?? "") ? error.code : "CHECK_CONFIGURATION";
  console.error(`Read-only migration status failed (${code}).`);
  process.exitCode = 1;
} finally {
  await client?.end().catch(() => {});
}
