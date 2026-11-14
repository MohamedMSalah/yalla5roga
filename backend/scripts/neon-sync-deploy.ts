/** Verify the configured Neon target; --apply deploys only reviewed, row-preserving migrations. */
import "dotenv/config";
import assert from "node:assert/strict";
import { Client } from "pg";
import { createHash, randomUUID } from "node:crypto";
import { mkdirSync, readFileSync, readdirSync, writeFileSync } from "node:fs";
import { createRequire } from "node:module";
import { spawn } from "node:child_process";

const apply = process.argv.includes("--apply");
const quote = (s: string) => '"' + s.replaceAll('"', '""') + '"';
const hash = (v: unknown) => createHash("sha256").update(JSON.stringify(v)).digest("hex");
const digest = (s: Buffer | string) => createHash("sha256").update(s).digest("hex");
const url = new URL(process.env.DATABASE_URL!);
url.searchParams.delete("channel_binding"); url.searchParams.delete("pgbouncer");
url.hostname = url.hostname.replace("-pooler.", ".");
const db = new Client({ connectionString: url.toString(), ssl: { rejectUnauthorized: true }, connectionTimeoutMillis: 20000 });
const names = readdirSync("prisma/migrations").filter(n => /^\d/.test(n)).sort();
const allowed = new Set(["20261114000000_special_event_occasions", "20261114010000_voting_deadline_durations"]);
const sql = (name: string) => readFileSync(`prisma/migrations/${name}/migration.sql`, "utf8");
const report: Record<string, any> = { checkedAt: new Date().toISOString(), mode: apply ? "deploy" : "read-only" };
async function snapshot(tables: string[], schema = "public") {
  const result: Record<string, any> = {};
  for (const name of tables) {
    const { rows: [row] } = await db.query(`SELECT coalesce(jsonb_agg(to_jsonb(t) ORDER BY to_jsonb(t)::text),'[]'::jsonb) AS data FROM ${quote(schema)}.${quote(name)} t`);
    result[name] = { rows: row.data, checksum: hash(row.data) };
  }
  return result;
}
try {
  await db.connect();
  const { rows: [target] } = await db.query("SELECT current_database() AS database,current_user AS role,current_setting('neon.project_id',true) AS project,current_setting('neon.branch_id',true) AS branch");
  assert.equal(target.project, "rough-mountain-69896781"); assert.equal(target.branch, "br-fragrant-heart-avfm4h2t");
  assert.equal(target.database, "neondb"); assert.equal(target.role, "neondb_owner"); report.target = target;
  const { rows: history } = await db.query("SELECT migration_name,checksum,finished_at,rolled_back_at FROM public._prisma_migrations ORDER BY started_at");
  assert.ok(history.every(h => h.finished_at || h.rolled_back_at), "Unfinished migration requires investigation");
  const applied = history.filter(h => h.finished_at && !h.rolled_back_at);
  for (const row of applied) { assert.ok(names.includes(row.migration_name)); assert.equal(digest(sql(row.migration_name)), row.checksum, `Checksum mismatch: ${row.migration_name}`); }
  const pending = names.filter(n => !applied.some(h => h.migration_name === n));
  report.appliedBefore = applied.map(h => h.migration_name); report.pendingBefore = pending;
  console.log(JSON.stringify({ target, applied: applied.length, pending, mode: report.mode }));
  assert.ok(pending.every(n => allowed.has(n)), "Unexpected pending migration; review required before deployment");
  if (apply && pending.length) {
    const tables = (await db.query("SELECT tablename FROM pg_tables WHERE schemaname='public' ORDER BY tablename")).rows.map(r => r.tablename as string);
    await db.query("BEGIN ISOLATION LEVEL REPEATABLE READ READ ONLY");
    const before = await snapshot(tables);
    const constraints = (await db.query("SELECT c.relname AS table_name,conname,contype,pg_get_constraintdef(p.oid) AS definition FROM pg_constraint p JOIN pg_class c ON c.oid=p.conrelid WHERE p.connamespace='public'::regnamespace ORDER BY c.relname,conname")).rows;
    const indexes = (await db.query("SELECT tablename,indexname,indexdef FROM pg_indexes WHERE schemaname='public' ORDER BY tablename,indexname")).rows;
    const labels = (await db.query("SELECT enumlabel FROM pg_enum e JOIN pg_type t ON t.oid=e.enumtypid WHERE t.typnamespace='public'::regnamespace AND t.typname='outing_occasion' ORDER BY enumsortorder")).rows.map(r => r.enumlabel as string);
    await db.query("COMMIT");
    const directory = `.database-backups/github-sync-${new Date().toISOString().replaceAll(':', '-')}`;
    mkdirSync(directory, { recursive: true });
    const backupPath = `${directory}/snapshot.json`;
    writeFileSync(backupPath, JSON.stringify({ target, tables: before, constraints, indexes, occasionLabels: labels }, null, 2));
    const disk = JSON.parse(readFileSync(backupPath, "utf8"));
    for (const t of tables) assert.equal(hash(disk.tables[t].rows), disk.tables[t].checksum);
    const restore = `sync_restore_${randomUUID().replaceAll('-', '')}`; assert.match(restore, /^sync_restore_[a-f0-9]{32}$/);
    await db.query("BEGIN");
    try {
      await db.query("SET LOCAL lock_timeout='5s'");
      await db.query(`CREATE SCHEMA ${quote(restore)}`);
      await db.query(`SET LOCAL search_path TO ${quote(restore)},public`);
      await db.query(`CREATE TYPE ${quote(restore)}.outing_occasion AS ENUM (${labels.map(l => "'" + l.replaceAll("'", "''") + "'").join(',')})`);
      for (const t of tables) {
        await db.query(`CREATE TABLE ${quote(restore)}.${quote(t)} (LIKE public.${quote(t)} INCLUDING ALL)`);
        if (t === "outings") await db.query(`ALTER TABLE ${quote(restore)}.outings ALTER COLUMN occasion DROP DEFAULT, ALTER COLUMN occasion TYPE ${quote(restore)}.outing_occasion USING occasion::text::${quote(restore)}.outing_occasion, ALTER COLUMN occasion SET DEFAULT 'none'::${quote(restore)}.outing_occasion`);
        if (disk.tables[t].rows.length) await db.query(`INSERT INTO ${quote(restore)}.${quote(t)} SELECT * FROM jsonb_populate_recordset(NULL::${quote(restore)}.${quote(t)},$1::jsonb)`, [JSON.stringify(disk.tables[t].rows)]);
      }
      for (const c of constraints.filter(c => c.contype === 'f')) {
        const definition = c.definition.replace(/REFERENCES (?:public\.)?/g, `REFERENCES ${quote(restore)}.`);
        await db.query(`ALTER TABLE ${quote(restore)}.${quote(c.table_name)} ADD CONSTRAINT ${quote(c.conname)} ${definition}`);
      }
      for (const name of pending) await db.query(sql(name).replace(/^BEGIN;\s*$/mg, '').replace(/^COMMIT;\s*$/mg, '').replaceAll('ALTER TYPE "outing_occasion"', `ALTER TYPE ${quote(restore)}."outing_occasion"`));
      const recovered = await snapshot(tables, restore);
      for (const t of tables) assert.equal(recovered[t].checksum, before[t].checksum, `Recovery mismatch: ${t}`);
    } finally { await db.query("ROLLBACK"); }
    report.privateBackup = backupPath; report.backupSha256 = digest(readFileSync(backupPath));
    report.recoveryRehearsal = "All public tables restored with keys/indexes/FKs, exact pending SQL rehearsed with an isolated occasion enum; all row hashes matched; rolled back";
    report.tableCount = tables.length; report.rowCount = tables.reduce((n, t) => n + before[t].rows.length, 0);
    console.log(JSON.stringify({ backup: backupPath, recovery: "PASS", tableCount: report.tableCount, rowCount: report.rowCount }));
    const require = createRequire(import.meta.url);
    const child = spawn(process.execPath, [require.resolve("prisma/build/index.js"), "migrate", "deploy", "--schema", "prisma/schema.prisma"], { stdio: "inherit", env: process.env });
    const code = await new Promise<number | null>((resolve, reject) => { child.once("error", reject); child.once("exit", resolve); });
    assert.equal(code, 0, "Prisma deployment failed");
    const after = await snapshot(tables.filter(t => t !== "_prisma_migrations"));
    report.applicationRowsPreserved = tables.filter(t => t !== "_prisma_migrations").every(t => after[t].checksum === before[t].checksum);
    assert.ok(report.applicationRowsPreserved, "Application rows changed during deployment; inspect concurrent writes");
  }
  const completed = (await db.query("SELECT migration_name,checksum,finished_at FROM public._prisma_migrations WHERE finished_at IS NOT NULL AND rolled_back_at IS NULL ORDER BY migration_name")).rows;
  report.appliedAfter = completed;
  report.pendingAfter = names.filter(n => !completed.some(h => h.migration_name === n));
  report.occasionLabels = (await db.query("SELECT enumlabel FROM pg_enum e JOIN pg_type t ON t.oid=e.enumtypid WHERE t.typnamespace='public'::regnamespace AND t.typname='outing_occasion' ORDER BY enumsortorder")).rows.map(r => r.enumlabel);
  report.constraints = (await db.query("SELECT conname,convalidated,pg_get_constraintdef(oid) AS definition FROM pg_constraint WHERE connamespace='public'::regnamespace AND conname IN ('outings_type_group_consistency','outings_vote_deadline_range','outing_drafts_vote_deadline_range') ORDER BY conname")).rows;
  if (apply) { assert.equal(report.pendingAfter.length, 0); assert.ok(['celebration', 'other'].every(v => report.occasionLabels.includes(v))); }
  report.result = "PASS";
} catch (error) {
  report.result = "FAILED"; report.reason = error instanceof Error ? error.message : "Unknown error"; throw error;
} finally {
  await db.end();
  writeFileSync(`../docs/audit/NEON_GITHUB_SYNC_${apply ? 'DEPLOYMENT' : 'READBACK'}.json`, JSON.stringify(report, null, 2) + '\n');
}
