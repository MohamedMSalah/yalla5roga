/** HTTP/OpenAPI only; disposable PostgreSQL schema and controlled Firebase verifier. */
import "dotenv/config";
import assert from "node:assert/strict";
import {randomUUID} from "node:crypto";
import {readFileSync,readdirSync,writeFileSync} from "node:fs";
import {Client} from "pg";
import express from "express";
import swaggerUi from "swagger-ui-express";
const schema=`deadline_api_${randomUUID().replaceAll("-","")}`;
const url=new URL(process.env.DATABASE_URL!);
url.searchParams.delete("channel_binding");url.searchParams.delete("pgbouncer");url.searchParams.set("sslmode",process.env.PHASE3_SECURE_TUNNEL === "1" ? "disable" : "verify-full");url.hostname=url.hostname.replace("-pooler.",".");
const admin=new Client({connectionString:url.toString(),ssl:process.env.PHASE3_SECURE_TUNNEL === "1" && url.hostname === "127.0.0.1" ? false : {rejectUnauthorized:true},connectionTimeoutMillis:15000});
url.searchParams.set("schema",schema);url.searchParams.set("connection_limit","1");process.env.DATABASE_URL=url.toString();process.env.NODE_ENV="test";
let db:import("@prisma/client").PrismaClient|undefined,server:import("node:http").Server|undefined,madeSchema=false;
const rows:any[]=[];
const oldError=console.error;console.error=(m,...r)=>{if(typeof m==="string"&&m.startsWith("[Firebase Auth]"))return;oldError(m,...r);};
try{
 await admin.connect();assert.match(schema,/^deadline_api_[a-f0-9]{32}$/);
 await admin.query(`CREATE SCHEMA "${schema}"`);madeSchema=true;await admin.query(`SET search_path TO "${schema}"`);
 for(const m of readdirSync("prisma/migrations").filter(n=>/^\d/.test(n)).sort())
  await admin.query(readFileSync(`prisma/migrations/${m}/migration.sql`,"utf8").replace('CREATE SCHEMA IF NOT EXISTS "public";',''));

 const owner="deadline-owner",group=randomUUID();
 await admin.query("INSERT INTO users(id,name,phone) VALUES ($1,'Deadline tester','+15550002001')",[owner]);
 await admin.query("INSERT INTO groups(id,name,created_by) VALUES ($1,'Deadline group',$2)",[group,owner]);
 await admin.query("INSERT INTO group_members(group_id,user_id,role) VALUES ($1,$2,'owner')",[group,owner]);
 db=(await import("../src/config/database.js")).prisma;
 await db.$executeRawUnsafe(`SET search_path TO "${schema}"`);
 assert.equal(((await db.$queryRawUnsafe("SELECT current_schema() AS schema"))as any[])[0].schema,schema);
 const{swaggerSpec}=await import("../src/config/swagger.js");const spec=swaggerSpec as any;
 const operations=new Map<string,any>();for(const[path,item]of Object.entries(spec.paths)as any)for(const[method,op]of Object.entries(item)as any)if(op.operationId)operations.set(op.operationId,{path,method,...op});
 const{createAuthMiddleware}=await import("../src/middleware/auth.middleware.js");const{UnauthorizedError}=await import("../src/utils/errors.js");const{errorMiddleware}=await import("../src/middleware/error.middleware.js");
 const app=express();app.use(express.json());app.use("/api-docs",swaggerUi.serve,swaggerUi.setup(spec));
 app.use(createAuthMiddleware(async token=>{if(token!==owner)throw new UnauthorizedError("Invalid fixture token");return{uid:owner};}));
 for(const f of["drafts","crud"])app.use("/api/outings",(await import(`../src/routes/outings/outing.${f}.routes.js`)).default);
 app.use(errorMiddleware);server=app.listen(0,"127.0.0.1");await new Promise<void>(done=>server!.once("listening",done));
 const address=server.address()as import("node:net").AddressInfo,base=`http://127.0.0.1:${address.port}`;
 assert.equal((await fetch(base+"/api-docs/")).status,200);rows.push({scenario:"Swagger UI serves existing create/deadline contract",result:"PASS"});
 assert.equal(spec.components.schemas.CreateOutingRequest.properties.vote_deadline_hours.maximum,168);
 let outingId="00000000-0000-4000-8000-000000000000";
 async function call(id:string,status:number,body?:unknown,token:string|null=owner){
  const op=operations.get(id);assert.ok(op);const response=await fetch(base+op.path.replace(/\{\w+\}/g,outingId),{method:op.method.toUpperCase(),headers:{...(token?{Authorization:`Bearer ${token}`}:{ }),...(body!==undefined?{"Content-Type":"application/json"}:{})},body:body===undefined?undefined:JSON.stringify(body),signal:AbortSignal.timeout(30000)});
  const json=await response.json()as any;assert.equal(response.status,status,`${id}: ${JSON.stringify(json)}`);assert.ok(op.responses[String(status)],`Missing OpenAPI status ${status}`);assert.equal(json.success,status<400);rows.push({scenario:id,status,result:"PASS"});return json.data;
 }
 const now=Date.now(),schedule=new Date(now+10*86400000).toISOString();
 const fields={title:"Deadline sample",group_id:group,occasion:"none",scheduled_at:schedule};
 await call("createOuting",401,fields,null);await call("createOuting",401,fields,"invalid-fixture-token");
 for(const hours of[1,2,3,6,12,24,48,72,120,168]){
  const instant=new Date(now+hours*3600000).toISOString();const created=await call("createOuting",201,{...fields,vote_ends_at:instant,vote_deadline_hours:hours});outingId=created.id;
  assert.equal(Date.parse(created.vote_ends_at),Date.parse(instant));assert.equal(created.vote_deadline_hours,hours);
  const stored=await call("getOuting",200);assert.equal(stored.vote_ends_at,created.vote_ends_at);
 }
 const instant=new Date(now+6*3600000);
 const offset=new Date(instant.getTime()+2*3600000).toISOString().replace("Z","+02:00");
 const normalized=await call("createOuting",201,{...fields,vote_ends_at:offset});assert.equal(Date.parse(normalized.vote_ends_at),instant.getTime());
 await call("createOuting",400,fields);
 for(const deadline of[new Date(now-60000).toISOString(),schedule,new Date(Date.parse(schedule)+60000).toISOString()])await call("createOuting",400,{...fields,vote_ends_at:deadline});
 await call("createOuting",400,{...fields,vote_ends_at:"not-an-instant"});
 await call("createOuting",400,{...fields,scheduled_at:new Date(now+2*3600000).toISOString(),vote_deadline_hours:3});
 await call("createOuting",400,{...fields,vote_deadline_hours:169});
 const before=Date.now();const legacy=await call("createOuting",201,{...fields,vote_deadline_hours:168});
 assert.ok(Date.parse(legacy.vote_ends_at)>=before+168*3600000);
 const draft=await call("createOutingDraft",201,{title:"Seven day draft",group_id:group,vote_deadline_hours:168});assert.equal(draft.vote_deadline_hours,168);
 const drafts=await call("listOutingDrafts",200);assert.ok(drafts.some((item:any)=>item.id===draft.id&&item.vote_deadline_hours===168));
 rows.push({scenario:"All hour/day presets, canonical UTC, strict before-start validation and seven-day draft persistence",result:"PASS"});
}catch(error){rows.push({scenario:"Deadline HTTP verification",result:"FAIL",error:error instanceof Error?error.message:"Unknown error"});throw error;
}finally{
 if(server)await new Promise<void>(done=>server!.close(()=>done()));await db?.$disconnect();
 if(madeSchema){assert.match(schema,/^deadline_api_[a-f0-9]{32}$/);await admin.query(`DROP SCHEMA "${schema}" CASCADE`);}await admin.end();console.error=oldError;
 writeFileSync("../docs/audit/VOTING_DEADLINE_OPENAPI_RESULTS.json",JSON.stringify({checkedAt:new Date().toISOString(),mode:"HTTP/OpenAPI; real disposable PostgreSQL schema; controlled Firebase verifier; no workers",cleanup:madeSchema?"Disposable schema removed":"No test schema created",rows},null,2)+"\n");console.log(JSON.stringify({checks:rows.length,cleanup:"complete"}));
}
