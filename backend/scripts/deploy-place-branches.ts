/** Target-checked, backed-up deployment of the additive places migration. */
import assert from "node:assert/strict";
import { createHash, randomUUID } from "node:crypto";
import { mkdirSync, readFileSync, readdirSync, writeFileSync } from "node:fs";
import { createRequire } from "node:module";
import { spawn } from "node:child_process";
import { Client } from "pg";

const apply = process.argv.includes("--apply");
const migration = "20261115000000_place_brands";
const quote = (s: string) => '"' + s.replaceAll('"', '""') + '"';
const digest = (s: string) => createHash("sha256").update(s).digest("hex");
const checksum = (v: unknown) => digest(JSON.stringify(v));
const sql = (name: string) =>
  readFileSync(`prisma/migrations/${name}/migration.sql`, "utf8");
const migrationSql = sql(migration);
const url = new URL(process.env.DATABASE_URL!);
url.hostname = url.hostname.replace("-pooler.", ".");
url.searchParams.delete("channel_binding");
url.searchParams.delete("pgbouncer");
url.searchParams.set("sslmode", "verify-full");
const db = new Client({
  connectionString: url.toString(),
  connectionTimeoutMillis: 20000,
});
const report: Record<string, any> = {
  checkedAt: new Date().toISOString(),
  mode: apply ? "deploy" : "read-only",
  migration,
};
const columns: Record<string, string[]> = {};
async function snapshot(tables: string[], schema = "public") {
  const data: Record<string, { rows: any[]; checksum: string }> = {};
  for (const table of tables) {
    const {
      rows: [row],
    } = await db.query(
      `SELECT coalesce(jsonb_agg(to_jsonb(t) ORDER BY to_jsonb(t)::text),'[]'::jsonb) AS data FROM (SELECT ${columns[table]!.map(quote).join(",")} FROM ${quote(schema)}.${quote(table)}) t`,
    );
    data[table] = { rows: row.data, checksum: checksum(row.data) };
  }
  return data;
}
try {
  await db.connect();
  const {
    rows: [target],
  } = await db.query(
    "SELECT current_database() AS database,current_user AS role,current_setting('neon.project_id',true) AS project,current_setting('neon.branch_id',true) AS branch",
  );
  assert.equal(target.project, "rough-mountain-69896781");
  assert.equal(target.branch, "br-fragrant-heart-avfm4h2t");
  assert.equal(target.database, "neondb");
  assert.equal(target.role, "neondb_owner");
  report.target = target;
  const names = readdirSync("prisma/migrations")
    .filter((n) => /^\d/.test(n))
    .sort();
  const history = (
    await db.query(
      "SELECT migration_name,checksum,finished_at,rolled_back_at FROM public._prisma_migrations",
    )
  ).rows;
  assert.ok(
    history.every((h) => h.finished_at || h.rolled_back_at),
    "Unfinished migration requires investigation",
  );
  const applied = history.filter((h) => h.finished_at && !h.rolled_back_at);
  for (const h of applied)
    assert.equal(
      digest(sql(h.migration_name)),
      h.checksum,
      `Checksum mismatch: ${h.migration_name}`,
    );
  const pending = names.filter(
    (n) => !applied.some((h) => h.migration_name === n),
  );
  assert.ok(
    pending.every((n) => n === migration),
    "Unexpected pending migration",
  );
  report.pendingBefore = pending;
  console.log(JSON.stringify({ target, pending, mode: report.mode }));
  if (apply && pending.length) {
    const tables = (
      await db.query(
        "SELECT tablename FROM pg_tables WHERE schemaname='public' ORDER BY tablename",
      )
    ).rows.map((r) => r.tablename as string);
    await db.query("BEGIN ISOLATION LEVEL REPEATABLE READ READ ONLY");
    for (const table of tables)
      columns[table] = (
        await db.query(
          "SELECT column_name FROM information_schema.columns WHERE table_schema='public' AND table_name=$1 ORDER BY ordinal_position",
          [table],
        )
      ).rows.map((r) => r.column_name);
    const before = await snapshot(tables);
    const constraints = (
      await db.query(
        "SELECT c.relname AS table_name,conname,contype,pg_get_constraintdef(p.oid) AS definition FROM pg_constraint p JOIN pg_class c ON c.oid=p.conrelid WHERE p.connamespace='public'::regnamespace ORDER BY c.relname,conname",
      )
    ).rows;
    const indexes = (
      await db.query(
        "SELECT tablename,indexname,indexdef FROM pg_indexes WHERE schemaname='public' ORDER BY tablename,indexname",
      )
    ).rows;
    const labels = (
      await db.query(
        "SELECT enumlabel FROM pg_enum e JOIN pg_type t ON t.oid=e.enumtypid WHERE t.typnamespace='public'::regnamespace AND t.typname='notification_event_type' ORDER BY enumsortorder",
      )
    ).rows.map((r) => r.enumlabel as string);
    await db.query("COMMIT");
    const directory = `.database-backups/places-ingestion-${new Date().toISOString().replaceAll(":", "-")}`;
    mkdirSync(directory, { recursive: true });
    const backupPath = `${directory}/snapshot.json`;
    writeFileSync(
      backupPath,
      JSON.stringify(
        {
          target,
          columns,
          tables: before,
          constraints,
          indexes,
          notificationEventLabels: labels,
        },
        null,
        2,
      ),
    );
    const disk = JSON.parse(readFileSync(backupPath, "utf8"));
    for (const t of tables)
      assert.equal(checksum(disk.tables[t].rows), before[t]!.checksum);
    const restore = `places_restore_${randomUUID().replaceAll("-", "")}`;
    await db.query("BEGIN");
    try {
      await db.query("SET LOCAL lock_timeout='5s'");
      await db.query(`CREATE SCHEMA ${quote(restore)}`);
      await db.query(`SET LOCAL search_path TO ${quote(restore)},public`);
      await db.query(
        `CREATE TYPE ${quote(restore)}.notification_event_type AS ENUM (${labels.map((l) => "'" + l.replaceAll("'", "''") + "'").join(",")})`,
      );
      for (const t of tables) {
        await db.query(
          `CREATE TABLE ${quote(restore)}.${quote(t)} (LIKE public.${quote(t)} INCLUDING ALL)`,
        );
        if (before[t]!.rows.length)
          await db.query(
            `INSERT INTO ${quote(restore)}.${quote(t)} SELECT * FROM jsonb_populate_recordset(NULL::${quote(restore)}.${quote(t)},$1::jsonb)`,
            [JSON.stringify(before[t]!.rows)],
          );
      }
      for (const c of constraints.filter((c) => c.contype === "f"))
        await db.query(
          `ALTER TABLE ${quote(restore)}.${quote(c.table_name)} ADD CONSTRAINT ${quote(c.conname)} ${c.definition.replace(/REFERENCES (?:public\.)?/g, `REFERENCES ${quote(restore)}.`)}`,
        );
      await db.query(
        migrationSql.replaceAll(
          "ALTER TYPE notification_event_type",
          `ALTER TYPE ${quote(restore)}.notification_event_type`,
        ),
      );
      const recovered = await snapshot(tables, restore);
      for (const t of tables)
        assert.equal(
          recovered[t]!.checksum,
          before[t]!.checksum,
          `Restore mismatch: ${t}`,
        );
    } finally {
      await db.query("ROLLBACK");
    }
    report.privateBackup = backupPath;
    report.backupSha256 = digest(readFileSync(backupPath, "utf8"));
    report.rehearsal =
      "PASS: all public rows restored with keys/indexes/FKs; exact migration rehearsed using an isolated enum and rolled back";
    report.tableCount = tables.length;
    report.rowCount = tables.reduce((n, t) => n + before[t]!.rows.length, 0);
    console.log(
      JSON.stringify({
        backup: backupPath,
        rehearsal: "PASS",
        tables: report.tableCount,
        rows: report.rowCount,
      }),
    );
    assert.equal(
      sql(migration),
      migrationSql,
      "Migration changed since rehearsal",
    );
    const require = createRequire(import.meta.url);
    const child = spawn(
      process.execPath,
      [
        require.resolve("prisma/build/index.js"),
        "migrate",
        "deploy",
        "--schema",
        "prisma/schema.prisma",
      ],
      {
        stdio: "inherit",
        env: { ...process.env, DATABASE_URL: url.toString() },
      },
    );
    const code = await new Promise<number | null>((resolve, reject) => {
      child.once("error", reject);
      child.once("exit", resolve);
    });
    assert.equal(code, 0, "Prisma deployment failed");
    const appTables = tables.filter((t) => t !== "_prisma_migrations");
    const after = await snapshot(appTables);
    report.existingRowsPreserved = appTables.every(
      (t) => after[t]!.checksum === before[t]!.checksum,
    );
    report.changedTables = appTables.filter((t) => after[t]!.checksum !== before[t]!.checksum);
    const protectedTables = appTables.filter((t) => /^(places|place_|vibes|outings$|outing_votes$|outing_vote_options$|saved_)/.test(t));
    assert.ok(protectedTables.every((t) => after[t]!.checksum === before[t]!.checksum), "Catalog or outing relationship values changed; investigate before importing");
  }
  const completed = (
    await db.query(
      "SELECT migration_name,checksum FROM public._prisma_migrations WHERE finished_at IS NOT NULL AND rolled_back_at IS NULL ORDER BY migration_name",
    )
  ).rows;
  report.pendingAfter = names.filter(
    (n) => !completed.some((h) => h.migration_name === n),
  );
  report.appliedMigration =
    completed.find((h) => h.migration_name === migration) ?? null;
  report.columns = (
    await db.query(
      "SELECT column_name FROM information_schema.columns WHERE table_schema='public' AND table_name='places' AND column_name IN ('brand_id','branch_name','normalized_name','normalized_address')",
    )
  ).rows;
  report.taxonomy = report.appliedMigration
    ? (
        await db.query(
          "SELECT (SELECT count(*) FROM place_categories)::int AS categories,(SELECT count(*) FROM vibes)::int AS vibes",
        )
      ).rows[0]
    : null;
  if (apply) {
    assert.equal(report.pendingAfter.length, 0);
    assert.equal(report.appliedMigration.checksum, digest(migrationSql));
    assert.equal(report.columns.length, 4);
    assert.ok(report.taxonomy.categories >= 36);
    assert.ok(report.taxonomy.vibes >= 15);
  }
  report.result = "PASS";
  console.log(
    JSON.stringify({
      result: report.result,
      pending: report.pendingAfter,
      applied: Boolean(report.appliedMigration),
    }),
  );
} catch (error) {
  report.result = "FAILED";
  report.reason = error instanceof Error ? error.message : "Unknown failure";
  throw error;
} finally {
  await db.end();
  writeFileSync(
    `../docs/audit/PLACE_BRANCHES_MIGRATION_${apply ? "DEPLOYMENT" : "READBACK"}.json`,
    JSON.stringify(report, null, 2) + "\n",
  );
}
