/** Read-only confirmation after normal Prisma Migrate deployment. */
import "dotenv/config";
import {Client} from "pg";
import {createHash} from "node:crypto";
import {readFileSync,writeFileSync} from "node:fs";
import assert from "node:assert/strict";
const url=new URL(process.env.DATABASE_URL!);url.searchParams.delete("channel_binding");url.searchParams.delete("pgbouncer");
const tunneled=process.env.PHASE3_SECURE_TUNNEL === "1" && url.hostname === "127.0.0.1";
const db=new Client({connectionString:url.toString(),ssl:tunneled?false:{rejectUnauthorized:true},connectionTimeoutMillis:20000});
try{
 await db.connect();const{rows:[target]}=await db.query("SELECT current_database() AS database,current_user AS role,current_setting('neon.project_id',true) AS project,current_setting('neon.branch_id',true) AS branch");
 assert.equal(target.project,"rough-mountain-69896781");assert.equal(target.branch,"br-fragrant-heart-avfm4h2t");assert.equal(target.database,"neondb");
 const name="20261113180000_multi_location_ballots";
 const checksum=createHash("sha256").update(readFileSync(`prisma/migrations/${name}/migration.sql`)).digest("hex");
 const{rows:[migration]}=await db.query("SELECT migration_name,checksum,finished_at,rolled_back_at,applied_steps_count FROM public._prisma_migrations WHERE migration_name=$1 AND rolled_back_at IS NULL",[name]);
 assert.ok(migration?.finished_at);assert.equal(migration.checksum,checksum);assert.equal(migration.applied_steps_count,1);
 const{rows:[key]}=await db.query("SELECT pg_get_constraintdef(oid) AS definition FROM pg_constraint WHERE conrelid='public.outing_votes'::regclass AND contype='p'");assert.equal(key.definition,"PRIMARY KEY (outing_id, user_id, option_id)");
 const{rows:[votes]}=await db.query("SELECT coalesce(jsonb_agg(to_jsonb(t) ORDER BY to_jsonb(t)::text),'[]'::jsonb) AS data FROM public.outing_votes t");
 const backupReport=JSON.parse(readFileSync("../docs/audit/PHASE_3_DATABASE_BACKUP.json","utf8"));const snapshot=JSON.parse(readFileSync(backupReport.privateBackup,"utf8"));assert.equal(createHash("sha256").update(JSON.stringify(votes.data)).digest("hex"),snapshot.tables.outing_votes.checksum);
 const{rows:checks}=await db.query("SELECT conname,convalidated FROM pg_constraint WHERE conrelid='public.outing_votes'::regclass ORDER BY conname");assert.ok(checks.every(c=>c.convalidated));
 const{rows:temporarySchemas}=await db.query("SELECT nspname FROM pg_namespace WHERE nspname LIKE 'phase3_api_%' OR nspname LIKE 'phase3_restore_%'");assert.equal(temporarySchemas.length,0);
 const report={checkedAt:new Date().toISOString(),target,migration,primaryKey:key.definition,voteCount:votes.data.length,existingVotesPreserved:true,constraints:checks,temporarySchemasRemaining:temporarySchemas.length,transport:tunneled?"Prisma/pg through loopback to encrypted Neon WebSocket":"PostgreSQL TLS"};
 writeFileSync("../docs/audit/PHASE_3_DATABASE_DEPLOYMENT.json",JSON.stringify(report,null,2)+"\n");console.log(JSON.stringify(report));
}finally{await db.end();}
