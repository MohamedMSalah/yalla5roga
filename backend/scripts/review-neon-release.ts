/** Deployment check for an already migrated Neon target; refuses any pending SQL. */
import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { readFileSync, readdirSync, writeFileSync } from 'node:fs';
import { createRequire } from 'node:module';
import { spawn } from 'node:child_process';
import { Client } from 'pg';

const hash = (value: unknown) => createHash('sha256').update(typeof value === 'string' ? value : JSON.stringify(value)).digest('hex');
const quote = (value: string) => '"' + value.replaceAll('"', '""') + '"';
const url = new URL(process.env.DATABASE_URL!);
url.hostname = url.hostname.replace('-pooler.', '.');
url.searchParams.delete('channel_binding');
url.searchParams.delete('pgbouncer');
url.searchParams.set('sslmode', 'verify-full');
const db = new Client({connectionString: url.toString(), connectionTimeoutMillis: 20000});
const report: Record<string, any> = {checkedAt: new Date().toISOString(), mode: 'target-checked Prisma migrate deploy; pending migrations prohibited'};
const names = readdirSync('prisma/migrations').filter(name => /^\d/.test(name)).sort();
const local = names.map(name => ({name, checksum: hash(readFileSync(`prisma/migrations/${name}/migration.sql`, 'utf8'))}));
async function history() {
  return (await db.query('SELECT migration_name,checksum,finished_at,rolled_back_at FROM public._prisma_migrations ORDER BY migration_name,started_at')).rows;
}
async function schemaState() {
  const columns = (await db.query("SELECT table_name,column_name,data_type,udt_name,is_nullable,column_default FROM information_schema.columns WHERE table_schema='public' ORDER BY table_name,ordinal_position")).rows;
  const constraints = (await db.query("SELECT c.relname AS table_name,conname,convalidated,pg_get_constraintdef(p.oid) AS definition FROM pg_constraint p JOIN pg_class c ON c.oid=p.conrelid WHERE p.connamespace='public'::regnamespace ORDER BY c.relname,conname")).rows;
  const indexes = (await db.query("SELECT tablename,indexname,indexdef FROM pg_indexes WHERE schemaname='public' ORDER BY tablename,indexname")).rows;
  const enums = (await db.query("SELECT t.typname,e.enumlabel,e.enumsortorder FROM pg_enum e JOIN pg_type t ON t.oid=e.enumtypid WHERE t.typnamespace='public'::regnamespace ORDER BY t.typname,e.enumsortorder")).rows;
  return {columns, constraints, indexes, enums};
}
async function rowState() {
  const tables = (await db.query("SELECT tablename FROM pg_tables WHERE schemaname='public' AND tablename <> '_prisma_migrations' ORDER BY tablename")).rows;
  const snapshots = [];
  await db.query('BEGIN ISOLATION LEVEL REPEATABLE READ READ ONLY');
  try {
    for (const {tablename} of tables) {
      const row = (await db.query(`SELECT count(*)::int AS rows,md5(coalesce(string_agg(md5(to_jsonb(t)::text),'' ORDER BY md5(to_jsonb(t)::text)),'')) AS checksum FROM public.${quote(tablename)} t`)).rows[0];
      snapshots.push({table: tablename,...row});
    }
  } finally { await db.query('ROLLBACK'); }
  return snapshots;
}
try {
  await db.connect();
  const target = (await db.query("SELECT current_database() AS database,current_user AS role,current_setting('neon.project_id',true) AS project,current_setting('neon.branch_id',true) AS branch")).rows[0];
  assert.equal(target.database,'neondb');
  assert.equal(target.project,'rough-mountain-69896781');
  assert.equal(target.branch,'br-fragrant-heart-avfm4h2t');
  assert.equal(target.role,'neondb_owner');
  report.target = target;
  const beforeHistory = await history();
  assert.ok(beforeHistory.every(row => row.finished_at || row.rolled_back_at), 'Unfinished migration');
  const applied = beforeHistory.filter(row => row.finished_at && !row.rolled_back_at);
  assert.equal(applied.length, local.length, 'Migration history count differs; review required');
  for (const row of applied) assert.equal(local.find(item => item.name === row.migration_name)?.checksum, row.checksum, `Migration drift: ${row.migration_name}`);
  const pending = local.filter(item => !applied.some(row => row.migration_name === item.name));
  report.migrations = local;
  report.pendingBefore = pending.map(item => item.name);
  assert.equal(pending.length,0,'Pending SQL requires separate review, backup and rehearsal');
  const beforeSchema = await schemaState();
  const beforeRows = await rowState();
  report.schemaBeforeSha256 = hash(beforeSchema);
  report.applicationTables = beforeRows;
  console.log(JSON.stringify({target, applied: applied.length, pending: [], action: 'Prisma migrate deploy'}));
  const require = createRequire(import.meta.url);
  const child = spawn(process.execPath,[require.resolve('prisma/build/index.js'),'migrate','deploy','--schema','prisma/schema.prisma'],{stdio:'inherit',env:{...process.env,DATABASE_URL:url.toString()}});
  const code = await new Promise<number|null>((resolve,reject) => {child.once('error',reject);child.once('exit',resolve);});
  assert.equal(code,0,'Prisma deployment command failed');
  report.prismaExitCode = code;
  const afterHistory = await history();
  report.schemaAfterSha256 = hash(await schemaState());
  report.schemaUnchanged = report.schemaBeforeSha256 === report.schemaAfterSha256;
  report.historyUnchanged = hash(beforeHistory) === hash(afterHistory);
  report.applicationRowsUnchanged = hash(beforeRows) === hash(await rowState());
  report.pendingAfter = local.filter(item => !afterHistory.some(row => row.migration_name === item.name && row.finished_at && !row.rolled_back_at)).map(item => item.name);
  assert.ok(report.schemaUnchanged && report.historyUnchanged && report.applicationRowsUnchanged,'State changed during no-op deployment; investigate concurrent writes');
  assert.equal(report.pendingAfter.length,0);
  report.result = 'PASS';
  console.log(JSON.stringify({result:report.result, applied:applied.length, pending:report.pendingAfter, schemaUnchanged:report.schemaUnchanged, applicationRowsUnchanged:report.applicationRowsUnchanged}));
} catch (error) {
  report.result = 'FAIL';
  report.reason = error instanceof Error ? (error.message || error.name).replace(/postgres(?:ql)?:\/\/\S+/g,'[redacted]') : 'Unknown';
  report.connectionErrors = Array.isArray((error as any)?.errors) ? (error as any).errors.map((item: any) => ({code:item.code, message:String(item.message).replace(/postgres(?:ql)?:\/\/\S+/g,'[redacted]')})) : undefined;
  process.exitCode=1;
  console.log(JSON.stringify({result:report.result,reason:report.reason,connectionErrors:report.connectionErrors}));
} finally {
  await db.end();
  writeFileSync('../docs/audit/NEON_RELEASE_SYNC_RESULTS.json',JSON.stringify(report,null,2)+'\n');
}
