/** Private logical backup + rollback-only restore before Phase 3 migration deployment. */
import "dotenv/config";
import {Client} from "pg";
import {createHash,randomUUID} from "node:crypto";
import {mkdirSync,writeFileSync,readFileSync} from "node:fs";
import assert from "node:assert/strict";
const url=new URL(process.env.DATABASE_URL!);url.searchParams.delete("channel_binding");url.searchParams.delete("pgbouncer");
const tunneled=process.env.PHASE3_SECURE_TUNNEL === "1" && url.hostname === "127.0.0.1";
const db=new Client({connectionString:url.toString(),ssl:tunneled?false:{rejectUnauthorized:true},connectionTimeoutMillis:20000});
const quote=(name:string)=>'"'+name.replaceAll('"','""')+'"';
const hash=(value:unknown)=>createHash("sha256").update(JSON.stringify(value)).digest("hex");
const expectedProject="rough-mountain-69896781",expectedBranch="br-fragrant-heart-avfm4h2t";
try {
 await db.connect();
 const {rows:[target]}=await db.query("SELECT current_database() AS database,current_user AS role,current_setting('neon.project_id',true) AS project,current_setting('neon.branch_id',true) AS branch");
 assert.equal(target.project,expectedProject);assert.equal(target.branch,expectedBranch);assert.equal(target.database,"neondb");assert.equal(target.role,"neondb_owner");
 const {rows:tables}=await db.query("SELECT tablename FROM pg_tables WHERE schemaname='public' ORDER BY tablename");
 const backup:any={checkedAt:new Date().toISOString(),target,tables:{},constraints:[],indexes:[]};
 // Repeatable-read snapshot captures all tables and schema metadata together.
 await db.query("BEGIN ISOLATION LEVEL REPEATABLE READ READ ONLY");
 for(const {tablename} of tables){const {rows:[record]}=await db.query(`SELECT coalesce(jsonb_agg(to_jsonb(t) ORDER BY to_jsonb(t)::text),'[]'::jsonb) AS data FROM public.${quote(tablename)} t`);backup.tables[tablename]={rows:record.data,checksum:hash(record.data)};}
 backup.constraints=(await db.query("SELECT c.relname AS table_name,conname,contype,pg_get_constraintdef(p.oid) AS definition FROM pg_constraint p JOIN pg_class c ON c.oid=p.conrelid JOIN pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname='public' ORDER BY c.relname,conname")).rows;
 backup.indexes=(await db.query("SELECT tablename,indexname,indexdef FROM pg_indexes WHERE schemaname='public' ORDER BY tablename,indexname")).rows;
 await db.query("COMMIT");
 const directory=`.database-backups/phase3-${new Date().toISOString().replaceAll(':','-')}`;mkdirSync(directory,{recursive:true});
 const backupPath=directory+"/snapshot.json";writeFileSync(backupPath,JSON.stringify(backup,null,2));
 const disk=JSON.parse(readFileSync(backupPath,"utf8"));for(const table of Object.values(disk.tables) as any[])assert.equal(hash(table.rows),table.checksum);
 const restore=`phase3_restore_${randomUUID().replaceAll('-','')}`;assert.match(restore,/^phase3_restore_[a-f0-9]{32}$/);
 await db.query("BEGIN");
 try {
  await db.query(`CREATE SCHEMA ${quote(restore)}`);await db.query(`SET LOCAL search_path TO ${quote(restore)},public`);
  for(const {tablename} of tables){await db.query(`CREATE TABLE ${quote(restore)}.${quote(tablename)} (LIKE public.${quote(tablename)} INCLUDING ALL)`);const rows=disk.tables[tablename].rows;if(rows.length)await db.query(`INSERT INTO ${quote(restore)}.${quote(tablename)} SELECT * FROM jsonb_populate_recordset(NULL::public.${quote(tablename)},$1::jsonb)`,[JSON.stringify(rows)]);}
  for(const constraint of disk.constraints.filter((c:any)=>c.contype==='f')){
   const definition=constraint.definition.replace(/REFERENCES (?:public\.)?/g,`REFERENCES ${quote(restore)}.`);
   await db.query(`ALTER TABLE ${quote(restore)}.${quote(constraint.table_name)} ADD CONSTRAINT ${quote(constraint.conname)} ${definition}`);
  }
  for(const {tablename}of tables){const {rows:[record]}=await db.query(`SELECT coalesce(jsonb_agg(to_jsonb(t) ORDER BY to_jsonb(t)::text),'[]'::jsonb) AS data FROM ${quote(restore)}.${quote(tablename)} t`);assert.equal(hash(record.data),disk.tables[tablename].checksum,tablename);}
  // Rehearse the exact SQL against restored rows, retaining every selection.
  const sql=readFileSync("prisma/migrations/20261113180000_multi_location_ballots/migration.sql","utf8").replace(/^BEGIN;\s*$/mg,'').replace(/^COMMIT;\s*$/mg,'');
  await db.query(sql);
  const {rows:[votes]}=await db.query(`SELECT coalesce(jsonb_agg(to_jsonb(t) ORDER BY to_jsonb(t)::text),'[]'::jsonb) AS data FROM ${quote(restore)}.outing_votes t`);assert.equal(hash(votes.data),disk.tables.outing_votes.checksum);
 } finally {await db.query("ROLLBACK");}
 const report={checkedAt:new Date().toISOString(),target,privateBackup:backupPath,backupSha256:createHash("sha256").update(readFileSync(backupPath)).digest("hex"),tableCount:tables.length,rowCount:Object.values(disk.tables).reduce((n:number,t:any)=>n+t.rows.length,0),voteCount:disk.tables.outing_votes.rows.length,recovery:"Restored all tables, keys and foreign keys; all row checksums matched; exact migration rehearsed without vote loss; transaction rolled back"};
 writeFileSync("../docs/audit/PHASE_3_DATABASE_BACKUP.json",JSON.stringify(report,null,2)+"\n");console.log(JSON.stringify(report));
}finally{await db.end();}
