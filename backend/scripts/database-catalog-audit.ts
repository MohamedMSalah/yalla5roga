import "dotenv/config";
import { Client } from "pg";
import { mkdir, writeFile } from "node:fs/promises";
import path from "node:path";

// Read-only catalog and aggregate data audit. Never prints row values or secrets.
const connection = new URL(process.env.DATABASE_URL!);
connection.hostname = connection.hostname.replace("-pooler.", ".");
connection.searchParams.delete("channel_binding");
const db = new Client({ connectionString: connection.toString() });
const output = path.resolve(process.argv[2] ?? "../docs/audit/database/live-catalog.before.json");
try {
  await db.connect();
  await db.query("BEGIN TRANSACTION ISOLATION LEVEL REPEATABLE READ READ ONLY");
  const query = async (sql: string) => (await db.query(sql)).rows;
  const target = await query(`SELECT current_database() AS database, current_user AS role,
    version(), current_setting('server_version') AS server_version,
    current_setting('neon.project_id',true) AS neon_project_id,
    current_setting('neon.branch_id',true) AS neon_branch_id,
    current_setting('neon.timeline_id',true) AS neon_timeline_id`);
  const tables = await query(`SELECT c.relname AS table_name, c.relkind, c.reltuples::bigint AS estimated_rows,
    pg_total_relation_size(c.oid)::bigint AS total_bytes, obj_description(c.oid) AS comment
    FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
    WHERE n.nspname='public' AND c.relkind IN ('r','p','v','m') ORDER BY c.relname`);
  const columns = await query(`SELECT c.relname AS table_name,a.attname AS column_name,a.attnum AS ordinal_position,
    format_type(a.atttypid,a.atttypmod) AS sql_type,a.attnotnull AS not_null,
    pg_get_expr(d.adbin,d.adrelid) AS default_expression, a.attidentity AS identity,
    a.attgenerated AS generated, col_description(c.oid,a.attnum) AS comment
    FROM pg_attribute a JOIN pg_class c ON c.oid=a.attrelid JOIN pg_namespace n ON n.oid=c.relnamespace
    LEFT JOIN pg_attrdef d ON d.adrelid=c.oid AND d.adnum=a.attnum
    WHERE n.nspname='public' AND c.relkind IN ('r','p') AND a.attnum>0 AND NOT a.attisdropped
    ORDER BY c.relname,a.attnum`);
  const constraints = await query(`SELECT c.relname AS table_name,k.conname AS name,k.contype AS type,
    pg_get_constraintdef(k.oid,true) AS definition,k.convalidated AS validated,
    k.condeferrable AS deferrable,k.condeferred AS initially_deferred,
    ARRAY(SELECT a.attname::text FROM unnest(k.conkey) WITH ORDINALITY x(attnum,ord)
      JOIN pg_attribute a ON a.attrelid=k.conrelid AND a.attnum=x.attnum ORDER BY x.ord) AS columns,
    CASE WHEN k.confrelid<>0 THEN k.confrelid::regclass::text END AS references_table
    FROM pg_constraint k JOIN pg_class c ON c.oid=k.conrelid JOIN pg_namespace n ON n.oid=c.relnamespace
    WHERE n.nspname='public' ORDER BY c.relname,k.conname`);
  const indexes = await query(`SELECT c.relname AS table_name,i.relname AS name,
    pg_get_indexdef(i.oid) AS definition,x.indisunique AS unique,x.indisprimary AS primary,
    x.indisvalid AS valid,pg_get_expr(x.indpred,x.indrelid) AS predicate,
    pg_relation_size(i.oid)::bigint AS bytes,coalesce(s.idx_scan,0)::bigint AS scans
    FROM pg_index x JOIN pg_class c ON c.oid=x.indrelid JOIN pg_class i ON i.oid=x.indexrelid
    JOIN pg_namespace n ON n.oid=c.relnamespace LEFT JOIN pg_stat_user_indexes s ON s.indexrelid=i.oid
    WHERE n.nspname='public' ORDER BY c.relname,i.relname`);
  const enums = await query(`SELECT t.typname AS name,array_agg(e.enumlabel::text ORDER BY e.enumsortorder) AS values
    FROM pg_type t JOIN pg_enum e ON e.enumtypid=t.oid JOIN pg_namespace n ON n.oid=t.typnamespace
    WHERE n.nspname='public' GROUP BY t.typname ORDER BY t.typname`);
  const triggers = await query(`SELECT c.relname AS table_name,t.tgname AS name,pg_get_triggerdef(t.oid) AS definition
    FROM pg_trigger t JOIN pg_class c ON c.oid=t.tgrelid JOIN pg_namespace n ON n.oid=c.relnamespace
    WHERE n.nspname='public' AND NOT t.tgisinternal ORDER BY c.relname,t.tgname`);
  const rows: Record<string, number> = {};
  for (const table of tables.filter(t => ['r','p'].includes(t.relkind))) {
    const name = '"' + table.table_name.replaceAll('"','""') + '"';
    rows[table.table_name] = Number((await query(`SELECT count(*)::bigint AS count FROM public.${name}`))[0].count);
  }
  const hasColumn = (table: string, column: string) =>
    columns.some(row => row.table_name === table && row.column_name === column);
  const findings = await query(`SELECT
    (SELECT count(*)::int FROM users WHERE phone IS NULL) AS users_without_phone,
    (SELECT count(*)::int FROM users WHERE phone IS NOT NULL AND phone !~ '^\\+[1-9][0-9]{7,14}$') AS non_e164_users,
    ${hasColumn("users", "email") ? "(SELECT count(*)::int FROM users WHERE email IS NOT NULL)" : "0"} AS users_with_legacy_email,
    (SELECT count(*)::int FROM users WHERE password_hash IS NOT NULL) AS users_with_password,
    (SELECT count(*)::int FROM groups g WHERE NOT EXISTS(SELECT 1 FROM group_members m WHERE m.group_id=g.id AND m.role='owner')) AS groups_without_owner,
    (SELECT count(*)::int FROM outings o WHERE (type='group' AND group_id IS NULL) OR (type='special_event' AND group_id IS NOT NULL)) AS invalid_outing_type,
    ${hasColumn("outings", "suggested_by_user_id") ? "(SELECT count(*)::int FROM outings WHERE suggested_by_user_id IS NOT NULL)" : "0"} AS suggested_by_populated,
    (SELECT count(*)::int FROM group_invitations WHERE invited_phone !~ '^\\+[1-9][0-9]{7,14}$') AS non_e164_invites,
    (SELECT count(*)::int FROM notification_events WHERE channel::text IN ('email','sms')) AS unused_delivery_channels`);
  const migrations = await query(`SELECT migration_name,checksum,finished_at,rolled_back_at,applied_steps_count FROM _prisma_migrations ORDER BY started_at`);
  await db.query("COMMIT");
  await mkdir(path.dirname(output),{recursive:true});
  const report = {capturedAt:new Date().toISOString(),endpoint:connection.hostname,target:target[0],tables,columns,constraints,indexes,enums,triggers,rowCounts:rows,findings:findings[0],migrations};
  await writeFile(output,JSON.stringify(report,null,2)+"\n");
  console.log(JSON.stringify({output,endpoint:report.endpoint,target:report.target,tables:tables.length,columns:columns.length,constraints:constraints.length,indexes:indexes.length,rowCounts:rows,findings:report.findings},null,2));
} finally {await db.end();}
