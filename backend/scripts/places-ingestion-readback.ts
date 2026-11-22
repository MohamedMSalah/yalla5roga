import assert from "node:assert/strict";
import { readFileSync, writeFileSync } from "node:fs";
import { createHash } from "node:crypto";
import { Client } from "pg";
const deployment = JSON.parse(readFileSync("../docs/audit/PLACES_INGESTION_MIGRATION_DEPLOYMENT.json", "utf8"));
const backup = JSON.parse(readFileSync(deployment.privateBackup, "utf8"));
const digest = (v: string) => createHash("sha256").update(v).digest("hex");
const quote = (s: string) => '"' + s.replaceAll('"', '""') + '"';
const url = new URL(process.env.DATABASE_URL!);
url.hostname = url.hostname.replace("-pooler.", "."); url.searchParams.delete("channel_binding"); url.searchParams.delete("pgbouncer");
const db = new Client({ connectionString: url.toString(), connectionTimeoutMillis: 30000 });
const report: any = { checkedAt: new Date().toISOString(), migration: "20261114050000_places_free_ingestion", tables: {} };
try {
  await db.connect();
  report.target = (await db.query("SELECT current_database() AS database,current_setting('neon.project_id',true) AS project,current_setting('neon.branch_id',true) AS branch")).rows[0];
  assert.equal(report.target.project, backup.target.project); assert.equal(report.target.branch, backup.target.branch);
  report.migrationHistory = (await db.query("SELECT migration_name,checksum,finished_at FROM _prisma_migrations WHERE migration_name=$1", [report.migration])).rows[0];
  report.localChecksum = digest(readFileSync(`prisma/migrations/${report.migration}/migration.sql`, "utf8"));
  assert.equal(report.localChecksum, report.migrationHistory.checksum);
  for (const [table, before] of Object.entries(backup.tables) as any) {
    if (table === "_prisma_migrations") continue;
    const rows = (await db.query(`SELECT coalesce(jsonb_agg(to_jsonb(t) ORDER BY to_jsonb(t)::text),'[]'::jsonb) AS rows FROM (SELECT ${backup.columns[table].map(quote).join(",")} FROM ${quote(table)}) t`)).rows[0].rows;
    report.tables[table] = { before: before.rows.length, after: rows.length, originalColumnsMatch: digest(JSON.stringify(rows)) === before.checksum };
    if (!report.tables[table].originalColumnsMatch) {
      const key = (r: any) => r.id ?? JSON.stringify(r);
      const byId = new Map(rows.map((r: any) => [key(r), r]));
      report.tables[table].changedColumns = [...new Set(before.rows.flatMap((r: any) => {
        const current: any = byId.get(key(r)); return current ? Object.keys(r).filter((k) => JSON.stringify(r[k]) !== JSON.stringify(current[k])) : ["row_removed"];
      }))];
    }
  }
  report.allOriginalValuesPreserved = Object.values(report.tables).every((t: any) => t.originalColumnsMatch);
  console.log(JSON.stringify(report, null, 2));
} finally {
  writeFileSync("../docs/audit/PLACES_INGESTION_MIGRATION_READBACK.json", JSON.stringify(report, null, 2));
  await db.end();
}
