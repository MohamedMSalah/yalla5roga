/** HTTP/OpenAPI only; disposable PostgreSQL schema and controlled Firebase verifier. */
import "dotenv/config";
import assert from "node:assert/strict";
import {randomUUID} from "node:crypto";
import {readFileSync,readdirSync,writeFileSync} from "node:fs";
import {Client} from "pg";
import express from "express";
import swaggerUi from "swagger-ui-express";
const schema=`phase3_api_${randomUUID().replaceAll("-","")}`;
const url=new URL(process.env.DATABASE_URL!);
url.searchParams.delete("channel_binding");url.searchParams.delete("pgbouncer");url.searchParams.set("sslmode",process.env.PHASE3_SECURE_TUNNEL === "1" ? "disable" : "verify-full");url.hostname=url.hostname.replace("-pooler.",".");
const admin=new Client({connectionString:url.toString(),ssl:process.env.PHASE3_SECURE_TUNNEL === "1" && url.hostname === "127.0.0.1" ? false : {rejectUnauthorized:true},connectionTimeoutMillis:15000});
url.searchParams.set("schema",schema);url.searchParams.set("connection_limit","1");process.env.DATABASE_URL=url.toString();process.env.NODE_ENV="test";
let db:import("@prisma/client").PrismaClient|undefined,server:import("node:http").Server|undefined,madeSchema=false;
const rows:any[]=[];
const oldError=console.error;console.error=(m,...r)=>{if(typeof m==="string"&&m.startsWith("[Firebase Auth]"))return;oldError(m,...r);};
try{
 await admin.connect();assert.match(schema,/^phase3_api_[a-f0-9]{32}$/);
 await admin.query(`CREATE SCHEMA "${schema}"`);madeSchema=true;await admin.query(`SET search_path TO "${schema}"`);
 for(const m of readdirSync("prisma/migrations").filter(n=>/^\d/.test(n)&&!n.includes("multi_location_ballots")).sort())
  await admin.query(readFileSync(`prisma/migrations/${m}/migration.sql`,"utf8").replace('CREATE SCHEMA IF NOT EXISTS "public";',''));
 const owner="phase3-owner",member="phase3-member",outsider="phase3-outsider",group=randomUUID(),legacy=randomUUID(),first=randomUUID(),second=randomUUID();
 await admin.query(`INSERT INTO users(id,name,phone) VALUES ($1,'Owner','+15550001001'),($2,'Member','+15550001002'),($3,'Outsider','+15550001003')`,[owner,member,outsider]);
 await admin.query(`INSERT INTO groups(id,name,created_by) VALUES ($1,'Phase 3 group',$2)`,[group,owner]);
 await admin.query(`INSERT INTO group_members(group_id,user_id,role) VALUES ($1,$2,'owner'),($1,$3,'member')`,[group,owner,member]);
 await admin.query(`INSERT INTO outings(id,title,group_id,created_by,status,type,occasion,vote_ends_at) VALUES ($1,'Legacy ballot',$2,$3,'voting','group','none',now()+interval '1 day')`,[legacy,group,owner]);
 await admin.query(`INSERT INTO outing_vote_options(id,outing_id,label) VALUES ($1,$2,'First'),($3,$2,'Second')`,[first,legacy,second]);
 await admin.query(`INSERT INTO outing_votes(outing_id,user_id,option_id) VALUES ($1,$2,$3)`,[legacy,member,first]);
 await admin.query(readFileSync("prisma/migrations/20261113180000_multi_location_ballots/migration.sql","utf8"));
 db=(await import("../src/config/database.js")).prisma;
 await db.$executeRawUnsafe(`SET search_path TO "${schema}"`);
 assert.equal(((await db.$queryRawUnsafe("SELECT current_schema() AS schema")) as any[])[0].schema,schema,"Raw SQL must stay inside the disposable schema");
 const {swaggerSpec}=await import("../src/config/swagger.js"),spec=swaggerSpec as any;
 const operations=new Map<string,any>();for(const [path,item]of Object.entries(spec.paths)as any)for(const[method,op]of Object.entries(item)as any)if(op.operationId)operations.set(op.operationId,{path,method,...op});
 const {createAuthMiddleware}=await import("../src/middleware/auth.middleware.js");const{UnauthorizedError}=await import("../src/utils/errors.js");const{errorMiddleware}=await import("../src/middleware/error.middleware.js");
 const app=express();app.use(express.json());app.use("/api-docs",swaggerUi.serve,swaggerUi.setup(spec));
 app.use(createAuthMiddleware(async token=>{if(![owner,member,outsider].includes(token))throw new UnauthorizedError("Invalid fixture token");return{uid:token};}));
 for(const f of ["crud","participants","voting","saved","chat"])app.use("/api/outings",(await import(`../src/routes/outings/outing.${f}.routes.js`)).default);
 app.use(errorMiddleware);server=app.listen(0,"127.0.0.1");await new Promise<void>(done=>server!.once("listening",done));
 const base=`http://127.0.0.1:${(server.address()as import("node:net").AddressInfo).port}`;
 const resolve=(ref:string):any=>ref.slice(2).split("/").reduce((v:any,k:string)=>v[k],spec);
 function validate(s:any,v:any):void{
  if(!s)return;if(s.$ref)return validate(resolve(s.$ref),v);if(v===null&&s.nullable)return;for(const a of s.allOf??[])validate(a,v);
  if(s.enum)assert.ok(s.enum.includes(v));
  if(s.type==="object"){assert.ok(v&&typeof v==="object");for(const k of s.required??[])assert.ok(k in v,`Missing ${k}`);for(const[k,c]of Object.entries(s.properties??{}))if(k in v)validate(c,v[k]);}
  else if(s.type==="array"){assert.ok(Array.isArray(v));for(const c of v)validate(s.items,c);}else if(s.type==="integer")assert.ok(Number.isInteger(v));else if(s.type)assert.equal(typeof v,s.type);
 }
 let active=legacy;
 async function call(id:string,status:number,token:string|null=owner,body?:unknown){
  const op=operations.get(id);assert.ok(op,`Undocumented ${id}`);
  const response=await fetch(base+op.path.replace(/\{\w+\}/g,active),{method:op.method.toUpperCase(),headers:{...(token?{Authorization:`Bearer ${token}`}:{ }),...(body!==undefined?{"Content-Type":"application/json"}:{})},body:body===undefined?undefined:JSON.stringify(body),signal:AbortSignal.timeout(30000)});
  const json=await response.json()as any;assert.equal(response.status,status,`${id}: ${JSON.stringify(json)}`);
  const r=op.responses[String(status)];assert.ok(r,`${id}: undocumented ${status}`);validate((r.$ref?resolve(r.$ref):r).content?.["application/json"]?.schema,json);
  rows.push({scenario:id,status,result:"PASS"});if(rows.length%10===0)console.log(JSON.stringify({completed:rows.length,last:id}));return json.data;
 }
 assert.equal((await fetch(base+"/api-docs/")).status,200);
 const init=await(await fetch(base+"/api-docs/swagger-ui-init.js")).text();assert.deepEqual(JSON.parse(init.split("var options = ")[1]!.split(/;\r?\n/)[0]!).swaggerDoc,spec);
 rows.push({scenario:"Served Swagger matches generated OpenAPI",result:"PASS"});
 for(const id of["listCurrentUserOutings","getOuting","createOuting","updateOuting","cancelOuting","replaceOutingBallot","getVotingState","setOutingAttendance","listOutingArrivals","recordOutingArrival","saveOuting","unsaveOuting","listOutingMessages","sendOutingMessage"])
  for(const t of[null,"invalid-fixture-token"])await call(id,401,t);
 let state=await call("getVotingState",200,member);assert.deepEqual(state.my_option_ids,[first]);rows.push({scenario:"Migration preserves existing ballot",result:"PASS"});
 await call("replaceOutingBallot",200,member,{option_ids:[first,second]});state=await call("getVotingState",200,member);assert.equal(state.my_option_ids.length,2);assert.equal(state.voted_count,1);assert.equal(state.isClosed,false);
 await call("replaceOutingBallot",200,member,{option_ids:[second]});state=await call("getVotingState",200,member);assert.deepEqual(state.my_option_ids,[second]);
 await call("replaceOutingBallot",200,member,{option_ids:[]});
 await call("replaceOutingBallot",400,member,{option_ids:[first,first]});await call("replaceOutingBallot",400,member,{option_ids:[randomUUID()]});await call("replaceOutingBallot",403,outsider,{option_ids:[first]});
 await call("replaceOutingBallot",200,member,{option_ids:[first,second]});
 for(const status of["maybe","not_going","going"])await call("setOutingAttendance",200,member,{status});state=await call("getVotingState",200,member);assert.equal(state.my_option_ids.length,2);
 await call("replaceOutingBallot",200,owner,{option_ids:[first]});state=await call("getVotingState",200);assert.equal(state.outing.status,"confirmed");assert.equal(state.outing.winning_option_id,first);
 await call("replaceOutingBallot",409,member,{option_ids:[second]});
 const created=await call("createOuting",201,owner,{title:"Phase 3 plan",group_id:group,occasion:"none",vote_deadline_hours:3,scheduled_at:new Date(Date.now()+86400000).toISOString(),initial_vote_options:[{label:"A",latitude:30,longitude:31},{label:"B",latitude:30.1,longitude:31.1}]});active=created.outing?.id??created.id;assert.ok(active);
 await call("listOutingAttendance",200,member);await call("updateOuting",200,owner,{title:"Edited phase 3"});await call("setOutingAttendance",200,member,{status:"maybe"});await call("updateOuting",403,member,{title:"Denied"});await call("cancelOuting",403,member,{});
 state=await call("getVotingState",200);const options=state.options.map((o:any)=>o.id);await call("replaceOutingBallot",200,owner,{option_ids:options});await call("replaceOutingBallot",200,member,{option_ids:options});state=await call("getVotingState",200);assert.equal(state.isTied,true);assert.equal(state.isClosed,true);
 await call("breakTie",403,member,{});const broken=await call("breakTie",200,owner,{});assert.ok(options.includes(broken.winningOptionId));
 await call("saveOuting",201,member,{});await call("unsaveOuting",200,member);await call("sendOutingMessage",201,member,{text:"Phase 3 fixture",clientMessageId:randomUUID()});
 await db.outings.update({where:{id:active},data:{status:"past"}});await call("getOuting",200,member);await call("listOutingMessages",200,member);await call("sendOutingMessage",409,member,{text:"Closed",clientMessageId:randomUUID()});
 const arrival=await db.outings.create({data:{title:"GPS fixture",group_id:group,created_by:owner,status:"confirmed",type:"group",occasion:"none",location_name:"Venue",location_latitude:30,location_longitude:31,scheduled_at:new Date(Date.now()-60000),vote_ends_at:new Date(Date.now()+86400000)}});active=arrival.id;
 const roster=await call("listOutingArrivals",200,member);assert.equal(roster.open,true);
 await call("recordOutingArrival",403,outsider,{latitude:30,longitude:31,accuracy:5,captured_at:new Date().toISOString()});
 assert.equal((await call("recordOutingArrival",200,member,{latitude:31,longitude:32,accuracy:5,captured_at:new Date().toISOString()})).arrived,false);
 assert.equal((await call("recordOutingArrival",200,member,{latitude:30,longitude:31,accuracy:5,captured_at:new Date().toISOString()})).arrived,true);
 const fixed=await call("createOuting",201,owner,{title:"Fixed venue",group_id:group,occasion:"none",vote_deadline_hours:3,scheduled_at:new Date(Date.now()+86400000).toISOString(),location_name:"One venue",location_latitude:30,location_longitude:31});
 active=fixed.outing?.id??fixed.id;assert.equal((await call("getOuting",200,member)).status,"confirmed");
 await call("setOutingAttendance",200,member,{status:"going"});await call("cancelOuting",200,owner,{});assert.equal((await call("getOuting",200,member)).status,"cancelled");
 const expired=await db.outings.create({data:{title:"Expired vote",group_id:group,created_by:owner,status:"voting",type:"group",occasion:"none",vote_ends_at:new Date(Date.now()-60000)}});active=expired.id;
 await call("replaceOutingBallot",409,owner,{option_ids:[]});
 rows.push({scenario:"Multi-ballot distinct voters, existing unique-winner/tie resolution, RSVP independence, completed chat and GPS",result:"PASS"});
}catch(error){
 rows.push({scenario:"Authenticated HTTP behavior and migration rehearsal",result:"BLOCKED",reason:error instanceof Error ? error.name + ": " + ((error as any).code ?? "verification failure") : "Unknown error"});
 throw error;
}finally{
 if(server)await new Promise<void>(done=>server!.close(()=>done()));await db?.$disconnect();
 if(madeSchema){assert.match(schema,/^phase3_api_[a-f0-9]{32}$/);await admin.query(`DROP SCHEMA "${schema}" CASCADE`);}await admin.end();console.error=oldError;
 writeFileSync("../docs/audit/PHASE_3_OPENAPI_RESULTS.json",JSON.stringify({checkedAt:new Date().toISOString(),mode:"HTTP/OpenAPI only; disposable schema; controlled Firebase verifier; no workers or live migration",cleanup:madeSchema?"Disposable schema removed":"No test schema created",rows},null,2)+"\n");console.log(JSON.stringify({checks:rows.length,cleanup:"complete"}));
}
