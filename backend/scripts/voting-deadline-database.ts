/** Scoped, backed-up deployment of the existing duration checks. No new columns. */
import "dotenv/config";
import assert from "node:assert/strict";
import {Client} from "pg";
import {createHash,randomUUID} from "node:crypto";
import {mkdirSync,readFileSync,writeFileSync,copyFileSync} from "node:fs";
import {createRequire} from "node:module";
import {spawn} from "node:child_process";
const require=createRequire(import.meta.url),name="20261114010000_voting_deadline_durations";
const migrationPath=`prisma/migrations/${name}/migration.sql`,sql=readFileSync(migrationPath,"utf8");
const checksum=createHash("sha256").update(sql).digest("hex");
const url=new URL(process.env.DATABASE_URL!);url.searchParams.delete("channel_binding");url.searchParams.delete("pgbouncer");
const tunnel=process.env.PHASE3_SECURE_TUNNEL==="1"&&url.hostname==="127.0.0.1";
const db=new Client({connectionString:url.toString(),ssl:tunnel?false:{rejectUnauthorized:true},connectionTimeoutMillis:20000});
const hash=(value:unknown)=>createHash("sha256").update(JSON.stringify(value)).digest("hex");
const tables=["outings","outing_drafts"];
async function snapshot(){const result:Record<string,any>={};for(const table of tables){const{rows:[record]}=await db.query(`SELECT coalesce(jsonb_agg(to_jsonb(t) ORDER BY to_jsonb(t)::text),'[]'::jsonb) AS data FROM public."${table}" t`);result[table]={rows:record.data,checksum:hash(record.data)};}return result;}
try{
 await db.connect();const{rows:[target]}=await db.query("SELECT current_database() AS database,current_user AS role,current_setting('neon.project_id',true) AS project,current_setting('neon.branch_id',true) AS branch");
 assert.equal(target.project,"rough-mountain-69896781");assert.equal(target.branch,"br-fragrant-heart-avfm4h2t");assert.equal(target.database,"neondb");
 const{rows:history}=await db.query("SELECT migration_name,checksum,finished_at,rolled_back_at FROM public._prisma_migrations ORDER BY started_at");
 assert.ok(history.every(row=>row.finished_at||row.rolled_back_at),"Unfinished migration requires review");
 await db.query("BEGIN ISOLATION LEVEL REPEATABLE READ READ ONLY");const before=await snapshot();await db.query("COMMIT");
 const directory=`.database-backups/voting-deadline-${new Date().toISOString().replaceAll(':','-')}`;mkdirSync(directory,{recursive:true});
 const backupPath=directory+"/snapshot.json";writeFileSync(backupPath,JSON.stringify({target,tables:before},null,2));
 const disk=JSON.parse(readFileSync(backupPath,"utf8"));for(const table of tables)assert.equal(hash(disk.tables[table].rows),disk.tables[table].checksum);
 const restore=`deadline_restore_${randomUUID().replaceAll('-','')}`;assert.match(restore,/^deadline_restore_[a-f0-9]{32}$/);
 await db.query("BEGIN");try{
  await db.query(`CREATE SCHEMA "${restore}"`);await db.query(`SET LOCAL search_path TO "${restore}",public`);
  for(const table of tables){await db.query(`CREATE TABLE "${restore}"."${table}" (LIKE public."${table}" INCLUDING ALL)`);if(before[table].rows.length)await db.query(`INSERT INTO "${restore}"."${table}" SELECT * FROM jsonb_populate_recordset(NULL::public."${table}",$1::jsonb)`,[JSON.stringify(before[table].rows)]);}
  await db.query(sql.replace(/^BEGIN;\s*$/mg,'').replace(/^COMMIT;\s*$/mg,''));
  for(const table of tables){const{rows:[record]}=await db.query(`SELECT coalesce(jsonb_agg(to_jsonb(t) ORDER BY to_jsonb(t)::text),'[]'::jsonb) AS data FROM "${restore}"."${table}" t`);assert.equal(hash(record.data),before[table].checksum);}
 }finally{await db.query("ROLLBACK");}
 console.log(JSON.stringify({backup:backupPath,rehearsal:"PASS",rowCounts:Object.fromEntries(tables.map(t=>[t,before[t].rows.length]))}));
 const existing=history.find(row=>row.migration_name===name&&row.finished_at&&!row.rolled_back_at);
 if(existing)assert.equal(existing.checksum,checksum);
 if(!existing){
  // Copy only already-applied migrations and this one: other pending feature work is excluded.
  const scoped=directory+"/deploy";mkdirSync(scoped+"/migrations",{recursive:true});
  for(const row of history.filter(row=>row.finished_at&&!row.rolled_back_at)){
   const source=`prisma/migrations/${row.migration_name}/migration.sql`;
   assert.equal(createHash("sha256").update(readFileSync(source)).digest("hex"),row.checksum);
   mkdirSync(`${scoped}/migrations/${row.migration_name}`,{recursive:true});copyFileSync(source,`${scoped}/migrations/${row.migration_name}/migration.sql`);
  }
  mkdirSync(`${scoped}/migrations/${name}`,{recursive:true});writeFileSync(`${scoped}/migrations/${name}/migration.sql`,sql);
  writeFileSync(`${scoped}/migrations/migration_lock.toml`,'provider = "postgresql"\n');
  writeFileSync(`${scoped}/schema.prisma`,'datasource db {\n provider = "postgresql"\n url = env("DATABASE_URL")\n}\n');
  const child=spawn(process.execPath,[require.resolve("prisma/build/index.js"),"migrate","deploy","--schema",`${scoped}/schema.prisma`],{stdio:"inherit",env:process.env});
  const code=await new Promise<number|null>(done=>child.once("exit",done));assert.equal(code,0,"Prisma deployment failed");
 }
 const{rows:[applied]}=await db.query("SELECT migration_name,checksum,finished_at FROM public._prisma_migrations WHERE migration_name=$1 AND rolled_back_at IS NULL",[name]);assert.ok(applied.finished_at);assert.equal(applied.checksum,checksum);
 const{rows:checks}=await db.query("SELECT conname,convalidated,pg_get_constraintdef(oid) AS definition FROM pg_constraint WHERE connamespace='public'::regnamespace AND conname IN ('outings_vote_deadline_range','outing_drafts_vote_deadline_range') ORDER BY conname");assert.equal(checks.length,2);assert.ok(checks.every(row=>row.convalidated&&row.definition.includes('168')));
 const after=await snapshot();for(const table of tables)assert.equal(after[table].checksum,before[table].checksum,"Source rows changed during deployment");
 const report={checkedAt:new Date().toISOString(),target,migration:applied,privateBackup:backupPath,recoveryRehearsal:"Restored impacted tables with keys/checks, applied exact migration, verified row checksums, rolled back",rowsPreserved:true,rowCounts:Object.fromEntries(tables.map(t=>[t,after[t].rows.length])),constraints:checks,scope:"Only existing outing/draft duration constraints expanded; pending unrelated migrations excluded",alreadyApplied:!!existing};
 writeFileSync("../docs/audit/VOTING_DEADLINE_DATABASE_DEPLOYMENT.json",JSON.stringify(report,null,2)+"\n");console.log(JSON.stringify(report));
}finally{await db.end();}
