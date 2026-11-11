import "dotenv/config";
import { Client } from "pg";
import { createHash, randomUUID } from "node:crypto";
import { mkdir, readFile, writeFile } from "node:fs/promises";
import path from "node:path";

const quote = (value: string) => '"' + value.replaceAll('"','""') + '"';
const digest = (value: string) => createHash("sha256").update(value).digest("hex");
const connection = new URL(process.env.DATABASE_URL!);
connection.hostname = connection.hostname.replace("-pooler.", ".");
connection.searchParams.delete("channel_binding");
connection.searchParams.set("sslmode","verify-full");
const db = new Client({connectionString:connection.toString()});
const mode = process.argv[2];
const directory = path.resolve(process.argv[3] ?? `.database-backups/${new Date().toISOString().replaceAll(':','-')}`);
if (mode === 'backup' && !process.argv[4]) {
  throw Error("Use database-backup.ts backup <private backup directory> <fresh catalog JSON>");
}
if (!['backup','verify'].includes(mode)) {
  throw Error("Use database-backup.ts backup|verify <private backup directory> [catalog or migration files]");
}

try {
  await db.connect();
  if (mode === 'backup') {
    await db.query("BEGIN ISOLATION LEVEL REPEATABLE READ READ ONLY");
    const catalog = JSON.parse(await readFile(path.resolve(process.argv[4]!), 'utf8'));
    const target = (await db.query(`SELECT current_database() AS database,
      current_setting('neon.project_id',true) AS project_id,current_setting('neon.branch_id',true) AS branch_id`)).rows[0];
    if (target.database !== catalog.target.database ||
        target.project_id !== catalog.target.neon_project_id ||
        target.branch_id !== catalog.target.neon_branch_id ||
        connection.hostname !== catalog.endpoint) {
      throw Error("The backup connection does not match the catalog target");
    }
    const tables = catalog.tables.filter((table: any) => ['r','p'].includes(table.relkind));
    const schema: string[] = [];
    for (const type of catalog.enums) {
      schema.push(`CREATE TYPE ${quote(type.name)} AS ENUM (${type.values.map((value:string) => "'"+value.replaceAll("'","''")+"'").join(',')});`);
    }
    for (const table of tables) {
      const columns = catalog.columns.filter((column:any) => column.table_name===table.table_name);
      schema.push(`CREATE TABLE ${quote(table.table_name)} (${columns.map((column:any) => `${quote(column.column_name)} ${column.sql_type}${column.default_expression ? ' DEFAULT '+column.default_expression : ''}${column.not_null ? ' NOT NULL' : ''}`).join(',\n')});`);
    }
    const pre = catalog.constraints.filter((constraint:any) => ['p','u'].includes(constraint.type));
    const post = catalog.constraints.filter((constraint:any) => ['c','f','x'].includes(constraint.type));
    for (const constraint of pre) schema.push(`ALTER TABLE ${quote(constraint.table_name)} ADD CONSTRAINT ${quote(constraint.name)} ${constraint.definition};`);
    await mkdir(directory,{recursive:true,mode:0o700});
    const files: Array<{table:string;rows:number;sha256:string;file:string}> = [];
    for (const table of tables) {
      const rows = (await db.query(`SELECT row_to_json(t)::text AS value FROM public.${quote(table.table_name)} t ORDER BY md5(row_to_json(t)::text)`)).rows;
      const content = rows.map(row => row.value).join('\n')+(rows.length ? '\n' : '');
      const file = `${table.table_name}.jsonl`;
      await writeFile(path.join(directory,file),content,{mode:0o600});
      files.push({table:table.table_name,rows:rows.length,sha256:digest(content),file});
    }
    const after: string[] = [];
    const backing = new Set(pre.map((constraint:any) => constraint.name));
    for (const index of catalog.indexes.filter((index:any) => !backing.has(index.name))) after.push(index.definition.replace(' ON public.',' ON ')+";");
    for (const constraint of post) after.push(`ALTER TABLE ${quote(constraint.table_name)} ADD CONSTRAINT ${quote(constraint.name)} ${constraint.definition};`);
    if(catalog.triggers.length) throw Error('Custom triggers require explicit backup support before proceeding');
    const beforeSql=schema.join('\n'); const afterSql=after.join('\n');
    await writeFile(path.join(directory,'schema-before-data.sql'),beforeSql,{mode:0o600});
    await writeFile(path.join(directory,'schema-after-data.sql'),afterSql,{mode:0o600});
    await writeFile(path.join(directory,'catalog.json'),JSON.stringify(catalog,null,2),{mode:0o600});
    await writeFile(path.join(directory,'manifest.json'),JSON.stringify({createdAt:new Date().toISOString(),target,endpoint:connection.hostname,files,schemaBeforeSha256:digest(beforeSql),schemaAfterSha256:digest(afterSql)},null,2),{mode:0o600});
    await db.query('COMMIT');
    console.log(JSON.stringify({mode,directory,target,tables:files.length,rows:files.reduce((sum,file) => sum+file.rows,0),checksums:'sha256 per table and schema file'}));
  } else {
    const manifest=JSON.parse(await readFile(path.join(directory,'manifest.json'),'utf8'));
    const before=await readFile(path.join(directory,'schema-before-data.sql'),'utf8');
    const after=await readFile(path.join(directory,'schema-after-data.sql'),'utf8');
    if(digest(before)!==manifest.schemaBeforeSha256 || digest(after)!==manifest.schemaAfterSha256) throw Error('Backup schema checksum mismatch');
    const values = new Map<string,string>();
    for (const file of manifest.files) {
      const content=await readFile(path.join(directory,file.file),'utf8');
      if(digest(content)!==file.sha256) throw Error(`Backup checksum mismatch for ${file.table}`);
      values.set(file.table,content);
    }
    // Recovery rehearsal is isolated to a unique schema and always rolled back.
    const restoreSchema='audit_restore_'+randomUUID().replaceAll('-','');
    await db.query('BEGIN');
    try {
      await db.query(`CREATE SCHEMA ${quote(restoreSchema)}`);
      await db.query(`SET LOCAL search_path TO ${quote(restoreSchema)},pg_catalog`);
      await db.query(before);
      for(const file of manifest.files) {
        const lines=values.get(file.table)!.trim();
        if(lines) await db.query(`INSERT INTO ${quote(restoreSchema)}.${quote(file.table)} SELECT * FROM jsonb_populate_recordset(NULL::${quote(restoreSchema)}.${quote(file.table)},$1::jsonb)`,['['+lines.split('\n').join(',')+']']);
      }
      await db.query(after.replaceAll('REFERENCES public.','REFERENCES '+quote(restoreSchema)+'.'));
      for(const file of manifest.files) {
        const rows=(await db.query(`SELECT row_to_json(t)::text AS value FROM ${quote(restoreSchema)}.${quote(file.table)} t ORDER BY md5(row_to_json(t)::text)`)).rows;
        const content=rows.map(row=>row.value).join('\n')+(rows.length?'\n':'');
        if(rows.length!==file.rows || digest(content)!==file.sha256) throw Error(`Restored data mismatch for ${file.table}`);
      }
      const migrations = [];
      for (const file of process.argv.slice(4)) {
        const sql = await readFile(file, 'utf8');
        const body = sql.match(/^(?:--[^\n]*\r?\n)*BEGIN;([\s\S]+)COMMIT;\s*$/)?.[1];
        if (!body || /\b(?:COMMIT|ROLLBACK|START TRANSACTION|SET\s+(?:LOCAL\s+)?search_path)\b/i.test(body)) {
          throw Error("Rehearsal requires a single transaction with no search_path changes");
        }
        await db.query(body);
        migrations.push({ name: path.basename(path.dirname(file)), sha256: digest(sql) });
      }
      for (const file of manifest.files) {
        const { rows: [row] } = await db.query(`SELECT count(*)::int AS count FROM ${quote(restoreSchema)}.${quote(file.table)}`);
        if (row.count !== file.rows) throw Error(`Migration changed the row count for ${file.table}`);
      }
      const report={verifiedAt:new Date().toISOString(),directory,restoredTables:manifest.files.length,restoredRows:manifest.files.reduce((sum:number,file:any)=>sum+file.rows,0),allChecksumsMatch:true,foreignKeysAndIndexesRestored:true,migrations,rolledBack:true};
      await db.query('ROLLBACK');
      await writeFile(path.join(directory,'recovery-verification.json'),JSON.stringify(report,null,2),{mode:0o600});
      console.log(JSON.stringify(report));
    } catch(error) {await db.query('ROLLBACK'); throw error;}
  }
} finally {await db.end();}
