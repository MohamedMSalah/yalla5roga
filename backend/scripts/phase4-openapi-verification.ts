/** HTTP/OpenAPI only; disposable PostgreSQL schema and controlled Firebase verifier. */
import "dotenv/config";
import assert from "node:assert/strict";
import {randomUUID} from "node:crypto";
import {readFileSync,readdirSync,writeFileSync} from "node:fs";
import {Client} from "pg";
import express from "express";
import swaggerUi from "swagger-ui-express";
const schema=`phase4_api_${randomUUID().replaceAll("-","")}`;
const url=new URL(process.env.DATABASE_URL!);
url.searchParams.delete("channel_binding");url.searchParams.delete("pgbouncer");url.searchParams.set("sslmode",process.env.PHASE3_SECURE_TUNNEL === "1" ? "disable" : "verify-full");url.hostname=url.hostname.replace("-pooler.",".");
const admin=new Client({connectionString:url.toString(),ssl:process.env.PHASE3_SECURE_TUNNEL === "1" && url.hostname === "127.0.0.1" ? false : {rejectUnauthorized:true},connectionTimeoutMillis:15000});
url.searchParams.set("schema",schema);url.searchParams.set("connection_limit","1");process.env.DATABASE_URL=url.toString();process.env.NODE_ENV="test";
let db:import("@prisma/client").PrismaClient|undefined,server:import("node:http").Server|undefined,madeSchema=false;
const rows:any[]=[];
const oldError=console.error;console.error=(m,...r)=>{if(typeof m==="string"&&m.startsWith("[Firebase Auth]"))return;oldError(m,...r);};
try{
 await admin.connect();assert.match(schema,/^phase4_api_[a-f0-9]{32}$/);
 await admin.query(`CREATE SCHEMA "${schema}"`);madeSchema=true;await admin.query(`SET search_path TO "${schema}"`);
 for(const m of readdirSync("prisma/migrations").filter(n=>/^\d/.test(n)&&n<"20261114000000_special_event_occasions").sort())
  await admin.query(readFileSync(`prisma/migrations/${m}/migration.sql`,"utf8").replace('CREATE SCHEMA IF NOT EXISTS "public";',''));
 const owner="phase4-owner",member="phase4-member",outsider="phase4-outsider",group=randomUUID(),legacy=randomUUID();
 await admin.query(`INSERT INTO users(id,name,phone) VALUES ($1,'Owner','+15550001001'),($2,'Member','+15550001002'),($3,'Outsider','+201000000003')`,[owner,member,outsider]);
 await admin.query(`INSERT INTO groups(id,name,created_by) VALUES ($1,'Phase 4 group',$2)`,[group,owner]);
 await admin.query(`INSERT INTO group_members(group_id,user_id,role) VALUES ($1,$2,'owner'),($1,$3,'member')`,[group,owner,member]);
 // A pending group invitation confers no membership.
 await admin.query(`INSERT INTO group_invitations(group_id,invited_phone,invited_by_user_id,user_id,status,expires_at) VALUES ($1,'+201000000003',$2,$3,'pending',now()+interval '1 day')`,[group,owner,outsider]);
 const legacyEvents=[{id:randomUUID(),occasion:"birthday"},{id:randomUUID(),occasion:"wedding"}];
 for(const old of legacyEvents)await admin.query(`INSERT INTO outings(id,title,created_by,type,occasion,status,scheduled_at,location_name) VALUES ($1,'Existing event',$2,'special_event',$3,'confirmed',now()+interval '2 days','Existing venue')`,[old.id,owner,old.occasion]);
 for(const m of readdirSync("prisma/migrations").filter(n=>/^\d/.test(n)&&n>="20261114000000_special_event_occasions").sort())
   await admin.query(readFileSync(`prisma/migrations/${m}/migration.sql`,"utf8"));
 db=(await import("../src/config/database.js")).prisma;
 await db.$executeRawUnsafe(`SET search_path TO "${schema}"`);
 assert.equal(((await db.$queryRawUnsafe("SELECT current_schema() AS schema")) as any[])[0].schema,schema,"Raw SQL must stay inside the disposable schema");
 const {swaggerSpec}=await import("../src/config/swagger.js"),spec=swaggerSpec as any;
 const operations=new Map<string,any>();for(const [path,item]of Object.entries(spec.paths)as any)for(const[method,op]of Object.entries(item)as any)if(op.operationId)operations.set(op.operationId,{path,method,...op});
 const {createAuthMiddleware}=await import("../src/middleware/auth.middleware.js");const{UnauthorizedError}=await import("../src/utils/errors.js");const{errorMiddleware}=await import("../src/middleware/error.middleware.js");
 const app=express();app.use(express.json());app.use("/api-docs",swaggerUi.serve,swaggerUi.setup(spec));
 app.use(createAuthMiddleware(async token=>{if(![owner,member,outsider].includes(token))throw new UnauthorizedError("Invalid fixture token");return{uid:token};}));
 for(const f of ["saved","drafts","participants","voting","chat","crud"])app.use("/api/outings",(await import(`../src/routes/outings/outing.${f}.routes.js`)).default);
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
 for(const id of["createOuting","updateOuting","getOuting","listCurrentUserOutings"])
  for(const t of[null,"invalid-fixture-token"])await call(id,401,t);
 for(const old of legacyEvents){active=old.id;const row=await call("getOuting",200);assert.equal(row.id,old.id);assert.equal(row.occasion,old.occasion);assert.equal(row.location_name,"Existing venue");}
 rows.push({scenario:"Additive migration preserves existing birthday and wedding IDs, occasions and venues",result:"PASS"});
 const requestSchema=spec.components.schemas.CreateOutingRequest;
 assert.deepEqual(requestSchema.properties.occasion.enum,["none","birthday","wedding","celebration","other"]);
 const baseEvent={title:"Phase 4 event",vote_deadline_hours:3,
   scheduled_at:new Date(Date.now()+86400000).toISOString(),
   location_name:"Event venue",location_latitude:30,location_longitude:31};
 for(const occasion of ["birthday","wedding","celebration","other"]){
   for(const group_id of [null,group]){
     const created=await call("createOuting",201,group_id?member:owner,{...baseEvent,occasion,group_id,create_request_key:randomUUID()});
     active=created.id;assert.ok(active);assert.equal(created.type,"special_event");assert.equal(created.occasion,occasion);assert.equal(created.group_id,group_id);
     const fetched=await call("getOuting",200,group_id?owner:owner);assert.equal(fetched.occasion,occasion);
     await call("getOuting",403,outsider);
     if(!group_id)await call("getOuting",403,member);
     const mine=await call("listCurrentUserOutings",200,group_id?member:owner);assert.ok(mine.some((o:any)=>o.id===active));
     rows.push({scenario:`${occasion}: ${group_id?"group-associated accepted member":"independent"} creates and round-trips as special_event`,result:"PASS"});
   }
   await call("createOuting",403,outsider,{...baseEvent,occasion,group_id:group});
 }
 for(const occasion of ["birthday","wedding","celebration","other"]){
   const draft=await call("createOutingDraft",201,owner,{title:"Event draft",occasion,special_event:true,group_id:group});active=draft.id;
   const edited=await call("updateOutingDraft",200,owner,{occasion,group_id:null});assert.equal(edited.occasion,occasion);assert.equal(edited.group_id,null);
   const drafts=await call("listOutingDrafts",200,owner);assert.ok(drafts.some((d:any)=>d.id===active&&d.occasion===occasion));
 }
 const outsideEvent=await call("createOuting",201,outsider,{...baseEvent,occasion:"other"});active=outsideEvent.id;
 await call("updateOuting",403,outsider,{group_id:group});
 await call("createOuting",404,owner,{...baseEvent,occasion:"other",group_id:randomUUID()});
 await call("createOuting",400,owner,{...baseEvent,occasion:"unknown"});
 await call("createOuting",400,owner,{...baseEvent,occasion:"none"});
 await call("createOuting",400,owner,{...baseEvent,occasion:"other",scheduled_at:null});
 await call("createOuting",400,owner,{...baseEvent,occasion:"other",scheduled_at:new Date(Date.now()-60000).toISOString()});
 await call("createOuting",400,owner,{...baseEvent,occasion:"other",location_name:null});
 await call("createOuting",400,owner,{...baseEvent,occasion:"other",group_id:group,initial_vote_options:[{label:"A"},{label:"B"}]});
 const regular=await call("createOuting",201,owner,{...baseEvent,occasion:"none",group_id:group});assert.equal(regular.type,"group");
 const independent=await call("createOuting",201,owner,{...baseEvent,occasion:"other"});active=independent.id;
 await call("getOuting",403,member);
 let changed=await call("updateOuting",200,owner,{group_id:group,occasion:"celebration"});assert.equal(changed.type,"special_event");
 await call("getOuting",200,member);await call("getOuting",403,outsider);
 changed=await call("updateOuting",200,owner,{group_id:null});assert.equal(changed.type,"special_event");
 await call("getOuting",403,member);await call("updateOuting",403,member,{occasion:"wedding"});
 await call("updateOuting",400,owner,{occasion:"none"});
 // Existing independent invitation flow and group-associated phone guests.
 for(const group_id of [null,group]){
   const request={...baseEvent,occasion:"celebration",group_id,guest_phones:["+201000000003","+201000000003"],guest_phones_whatsapp_opt_in:true,create_request_key:randomUUID()};
   const first=await call("createOuting",201,owner,request);active=first.id;
   const retry=await call("createOuting",201,owner,request);assert.equal(retry.id,first.id);
   assert.ok(first.manual_whatsapp_urls?.length===1 || await db.notification_events.count({where:{outing_id:active,channel:"whatsapp"}})===1);
   await call("inviteOutingGuest",201,owner,{user_id:outsider});
   await call("getOuting",200,outsider);
   await call("acceptOutingInvitation",200,outsider,{});
   await call("setOutingAttendance",200,outsider,{status:"going"});
   rows.push({scenario:`${group_id?"Group-associated":"Independent"} event: deduplicated phone invitations, idempotent retry, app invite acceptance and RSVP`,result:"PASS"});
 }
 await call("createOuting",400,owner,{...baseEvent,occasion:"wedding",guest_phones:["+201000000003"],create_request_key:randomUUID()});
 rows.push({scenario:"Four occasions, optional group membership and privacy, standard outings, validation, guest invitations, idempotency and RSVP",result:"PASS"});
}catch(error){
 rows.push({scenario:"Authenticated HTTP behavior and migration rehearsal",result:"BLOCKED",reason:error instanceof Error ? error.name + ": " + ((error as any).code ?? "verification failure") : "Unknown error"});
 throw error;
}finally{
 if(server)await new Promise<void>(done=>server!.close(()=>done()));await db?.$disconnect();
 if(madeSchema){await admin.query("ROLLBACK");assert.match(schema,/^phase4_api_[a-f0-9]{32}$/);await admin.query(`DROP SCHEMA "${schema}" CASCADE`);}await admin.end();console.error=oldError;
 writeFileSync("../docs/audit/PHASE_4_OPENAPI_RESULTS.json",JSON.stringify({checkedAt:new Date().toISOString(),mode:"HTTP/OpenAPI only; disposable schema; controlled Firebase verifier; no workers or live migration",cleanup:madeSchema?"Disposable schema removed":"No test schema created",rows},null,2)+"\n");console.log(JSON.stringify({checks:rows.length,cleanup:"complete"}));
}
