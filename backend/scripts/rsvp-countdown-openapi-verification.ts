/** HTTP/OpenAPI only; disposable PostgreSQL schema and controlled Firebase verifier. */
import "dotenv/config";
import assert from "node:assert/strict";
import {randomUUID} from "node:crypto";
import {readFileSync,readdirSync,writeFileSync} from "node:fs";
import {Client} from "pg";
import express from "express";
import swaggerUi from "swagger-ui-express";
const schema=`rsvp_api_${randomUUID().replaceAll("-","")}`;
const url=new URL(process.env.DATABASE_URL!);
url.searchParams.delete("channel_binding");url.searchParams.delete("pgbouncer");url.searchParams.set("sslmode",process.env.PHASE3_SECURE_TUNNEL === "1" ? "disable" : "verify-full");url.hostname=url.hostname.replace("-pooler.",".");
const admin=new Client({connectionString:url.toString(),ssl:process.env.PHASE3_SECURE_TUNNEL === "1" && url.hostname === "127.0.0.1" ? false : {rejectUnauthorized:true},connectionTimeoutMillis:15000});
url.searchParams.set("schema",schema);url.searchParams.set("connection_limit","1");process.env.DATABASE_URL=url.toString();process.env.NODE_ENV="test";
let db:import("@prisma/client").PrismaClient|undefined,server:import("node:http").Server|undefined,madeSchema=false;
const rows:any[]=[];
const oldError=console.error;console.error=(m,...r)=>{if(typeof m==="string"&&m.startsWith("[Firebase Auth]"))return;oldError(m,...r);};
try{
 await admin.connect();assert.match(schema,/^rsvp_api_[a-f0-9]{32}$/);
 await admin.query(`CREATE SCHEMA "${schema}"`);madeSchema=true;await admin.query(`SET search_path TO "${schema}"`);
 for(const m of readdirSync("prisma/migrations").filter(n=>/^\d/.test(n)).sort())
  await admin.query(readFileSync(`prisma/migrations/${m}/migration.sql`,"utf8").replace('CREATE SCHEMA IF NOT EXISTS "public";',''));


 const ids=["rsvp-owner","rsvp-one","rsvp-two","rsvp-pending"],group=randomUUID();
 await admin.query("INSERT INTO users(id,name,phone) VALUES ($1,'Owner','+15550003001'),($2,'Member one','+15550003002'),($3,'Member two','+15550003003'),($4,'Pending','+15550003004')",ids);
 await admin.query("INSERT INTO groups(id,name,created_by) VALUES ($1,'RSVP group',$2)",[group,ids[0]]);
 for(const [i,id] of ids.slice(0,3).entries())await admin.query("INSERT INTO group_members(group_id,user_id,role) VALUES ($1,$2,$3::group_role)",[group,id,i===0?"owner":"member"]);
 db=(await import("../src/config/database.js")).prisma;await db.$executeRawUnsafe(`SET search_path TO "${schema}"`);
 assert.equal(((await db.$queryRawUnsafe("SELECT current_schema() AS schema"))as any[])[0].schema,schema);
 const{swaggerSpec}=await import("../src/config/swagger.js");const spec=swaggerSpec as any;
 const operations=new Map<string,any>();for(const[path,item]of Object.entries(spec.paths)as any)for(const[method,op]of Object.entries(item)as any)if(op.operationId)operations.set(op.operationId,{path,method,...op});
 assert.ok(spec.components.schemas.AttendanceRosterEntry.properties.status.enum.includes("no_response"));
 assert.equal(spec.components.schemas.AttendanceRosterEntry.properties.updated_at.nullable,true);
 const{createAuthMiddleware}=await import("../src/middleware/auth.middleware.js"),{UnauthorizedError}=await import("../src/utils/errors.js"),{errorMiddleware}=await import("../src/middleware/error.middleware.js");
 const app=express();app.use(express.json());app.use("/api-docs",swaggerUi.serve,swaggerUi.setup(spec));
 app.use(createAuthMiddleware(async token=>{if(!ids.includes(token))throw new UnauthorizedError("Invalid fixture token");return{uid:token};}));
 for(const f of["crud","participants","voting"])app.use("/api/outings",(await import(`../src/routes/outings/outing.${f}.routes.js`)).default);
 app.use(errorMiddleware);server=app.listen(0,"127.0.0.1");await new Promise<void>(done=>server!.once("listening",done));
 const base=`http://127.0.0.1:${(server.address()as import("node:net").AddressInfo).port}`;
 assert.equal((await fetch(base+"/api-docs/")).status,200);
 let outingId="00000000-0000-4000-8000-000000000000";
 async function call(id:string,status:number,token:string|null=ids[0]!,body?:unknown){const op=operations.get(id);assert.ok(op);
 const response=await fetch(base+op.path.replace(/\{\w+\}/g,outingId),{method:op.method.toUpperCase(),headers:{...(token?{Authorization:`Bearer ${token}`}:{ }),...(body!==undefined?{"Content-Type":"application/json"}:{})},body:body===undefined?undefined:JSON.stringify(body),signal:AbortSignal.timeout(30000)});
 const json=await response.json()as any;assert.equal(response.status,status,`${id}: ${JSON.stringify(json)}`);assert.ok(op.responses[String(status)],`${id}: undocumented status ${status}`);rows.push({scenario:id,status,result:"PASS"});return json;}
 const created=await call("createOuting",201,ids[0],{title:"RSVP test plan",group_id:group,occasion:"none",vote_deadline_hours:3,scheduled_at:new Date(Date.now()+2*86400000).toISOString(),initial_vote_options:[{label:"Cafe A"},{label:"Cafe B"}]});outingId=created.data.id;
 await db.outing_guests.create({data:{outing_id:outingId,user_id:ids[3]!,status:"pending"}});
 await call("listOutingAttendance",401,null);await call("listOutingAttendance",401,"invalid-fixture-token");
 let roster=await call("listOutingAttendance",200,ids[1]);assert.equal(roster.data.length,3);assert.equal(roster.my_response,"no_response");assert.deepEqual(roster.summary,{going:1,maybe:0,not_going:0,no_response:2});
 assert.equal(roster.data.find((r:any)=>r.user_id===ids[1]).updated_at,null);
 assert.ok(roster.data.every((r:any)=>typeof r.users.name==="string"&&!("phone"in r.users)));
 const repeat=await call("listOutingAttendance",200,ids[1]);assert.deepEqual(repeat,roster);
 const voting=await call("getVotingState",200,ids[1]);const option=voting.data.options[0].id;
 await call("replaceOutingBallot",200,ids[1],{option_ids:[option]});
 roster=await call("listOutingAttendance",200,ids[1]);assert.equal(roster.my_response,"no_response");assert.equal(roster.summary.no_response,2);
 const changed=await call("setOutingAttendance",200,ids[1],{status:"maybe"});assert.equal(changed.my_response,"maybe");assert.equal(changed.items.length,3);assert.equal(changed.summary.no_response,1);
 await call("setOutingAttendance",200,ids[2],{status:"not_going"});
 roster=await call("listOutingAttendance",200,ids[2]);assert.equal(roster.my_response,"not_going");assert.equal(roster.summary.no_response,0);
 const independent=await call("getVotingState",200,ids[1]);assert.deepEqual(independent.data.my_option_ids,[option]);
 await call("listOutingAttendance",403,ids[3]);
 await call("acceptOutingInvitation",200,ids[3],{});
 roster=await call("listOutingAttendance",200,ids[3]);assert.equal(roster.my_response,"no_response");assert.equal(roster.data.length,4);assert.equal(roster.summary.no_response,1);
 await call("setOutingAttendance",400,ids[3],{status:"no_response"});
 const owner=await call("setOutingAttendance",200,ids[0],{status:"maybe"});assert.equal(owner.data.status,"going");
 rows.push({scenario:"Persistent unanswered default, complete phone-free roster, pending exclusion and accepted-member default; RSVP remains independent of location votes",result:"PASS"});
}catch(error){rows.push({scenario:"RSVP HTTP verification",result:"FAIL",error:error instanceof Error?error.message:"Unknown error"});throw error;
}finally{
 if(server)await new Promise<void>(done=>server!.close(()=>done()));await db?.$disconnect();
 if(madeSchema){assert.match(schema,/^rsvp_api_[a-f0-9]{32}$/);await admin.query(`DROP SCHEMA "${schema}" CASCADE`);}await admin.end();console.error=oldError;
 writeFileSync("../docs/audit/RSVP_COUNTDOWN_OPENAPI_RESULTS.json",JSON.stringify({checkedAt:new Date().toISOString(),mode:"HTTP/OpenAPI; disposable PostgreSQL schema; controlled Firebase verifier; no workers or schema deployment",cleanup:madeSchema?"Disposable schema removed":"No test schema created",rows},null,2)+"\n");console.log(JSON.stringify({checks:rows.length,cleanup:"complete"}));
}
