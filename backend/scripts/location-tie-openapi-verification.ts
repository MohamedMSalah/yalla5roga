/** Served Swagger HTTP verification, disposable local PostgreSQL only. */
import assert from "node:assert/strict";
import { randomUUID } from "node:crypto";
import { readFileSync,readdirSync,writeFileSync } from "node:fs";
import { resolve } from "node:path";
import { pathToFileURL } from "node:url";
import { Client } from "pg";
import express from "express";
import swaggerUi from "swagger-ui-express";
import { Server as SocketServer } from "socket.io";
import { io as socketClient, type Socket } from "socket.io-client";
const local = true;
let localDb: any, localServer: any;
let localConnection = "";
if (local) {
  const moduleAt = (path: string) => pathToFileURL(resolve(".places-data/branch-verification/node_modules", path)).href;
  const { PGlite } = await import(moduleAt("@electric-sql/pglite/dist/index.js"));
  const { PGLiteSocketServer } = await import(moduleAt("@electric-sql/pglite-socket/dist/index.js"));
  localDb = await PGlite.create();
  await localDb.exec("SET neon.project_id='local-fixture'; SET neon.branch_id='local-fixture'");
  localServer = new PGLiteSocketServer({ db: localDb, host: "127.0.0.1", port: 0, maxConnections: 2 });
  await localServer.start();
  localConnection = `postgresql://postgres:postgres@${localServer.getServerConn()}/postgres`;
}

const schema=`tie_verify_${randomUUID().replaceAll("-","")}`;
const url=new URL(localConnection);url.searchParams.set("sslmode","disable");url.searchParams.set("schema",schema);url.searchParams.set("connection_limit","1");
process.env.DATABASE_URL=url.toString();process.env.NODE_ENV="test";
const admin=new Client({connectionString:localConnection+"?sslmode=disable"});let db:any,server:any;
let realtime: SocketServer | undefined, socket: Socket | undefined;
const results:any[]=[];const pass=(scenario:string)=>{results.push({scenario,result:"PASS"});console.log(`PASS ${scenario}`);};
const originalError=console.error; console.error=(m,...rest)=>{if(typeof m==="string" && m.startsWith("[Firebase Auth]"))return;originalError(m,...rest);};
const creator="tie-creator",member="tie-member",groupOwner="tie-group-owner",third="tie-third";
try {
 await admin.connect();await admin.query(`CREATE SCHEMA "${schema}"; SET search_path TO "${schema}"`);
 const legacyOuting = randomUUID(), legacyOption = randomUUID();
 for (const migration of readdirSync("prisma/migrations").filter(name => /^\d/.test(name)).sort()) {
   if (migration === "20261115010000_location_voting_rounds") {
     await admin.query("INSERT INTO users (id, name, phone) VALUES ('legacy-creator', 'Legacy', '+15550008998')");
     await admin.query("INSERT INTO outings (id, title, created_by, type, occasion, status, location_name) VALUES ($1, 'Legacy outing', 'legacy-creator', 'special_event', 'birthday', 'confirmed', 'Legacy venue')", [legacyOuting]);
     await admin.query("INSERT INTO outing_vote_options (id, outing_id, label) VALUES ($1, $2, 'Legacy venue')", [legacyOption, legacyOuting]);
     await admin.query("UPDATE outings SET winning_option_id = $1, vote_closed_at = now() WHERE id = $2", [legacyOption, legacyOuting]);
     await admin.query("INSERT INTO outing_votes (outing_id, user_id, option_id) VALUES ($1, 'legacy-creator', $2)", [legacyOuting, legacyOption]);
     await admin.query("INSERT INTO outing_attendance (outing_id, user_id, status) VALUES ($1, 'legacy-creator', 'going')", [legacyOuting]);
   }
   await admin.query(readFileSync(`prisma/migrations/${migration}/migration.sql`, "utf8").replace('CREATE SCHEMA IF NOT EXISTS "public";', ""));
 }
 db=(await import("../src/config/database.js")).prisma;await db.$executeRawUnsafe(`SET search_path TO "${schema}"`);
 assert.equal((await db.$queryRawUnsafe("SELECT current_schema() AS name"))[0].name,schema);pass("All migrations apply in isolated local schema");
 for(const [i,id] of [creator,member,groupOwner,third].entries())await db.users.create({data:{id,name:id,phone:`+1555000800${i}`}});
 const group=await db.groups.create({data:{name:"Tie fixture",created_by:groupOwner}});
 await db.group_members.createMany({data:[creator,member,groupOwner,third].map(user_id=>({group_id:group.id,user_id}))});
 const {swaggerSpec}=await import("../src/config/swagger.js");const {createAuthMiddleware}=await import("../src/middleware/auth.middleware.js");const {UnauthorizedError}=await import("../src/utils/errors.js");const {errorMiddleware}=await import("../src/middleware/error.middleware.js");
 const app=express();app.use(express.json());app.use("/api-docs",swaggerUi.serve,swaggerUi.setup(swaggerSpec));app.use(createAuthMiddleware(async token=>{if(![creator,member,groupOwner,third,"tie-new-member","legacy-creator"].includes(token))throw new UnauthorizedError();return {uid:token};}));
 for(const f of ["voting","participants","crud"])app.use("/api/outings",(await import(`../src/routes/outings/outing.${f}.routes.js`)).default);
 app.use(errorMiddleware);server=app.listen(0,"127.0.0.1");await new Promise<void>(r=>server.once("listening",r));
 const base=`http://127.0.0.1:${server.address().port}`;const init=await(await fetch(base+"/api-docs/swagger-ui-init.js")).text();const spec=JSON.parse(init.split("var options = ")[1]!.split(/;\r?\n/)[0]!).swaggerDoc;
 const ops=new Map<string,any>();for(const [path,item]of Object.entries(spec.paths)as any)for(const [method,op]of Object.entries(item)as any)if(op.operationId)ops.set(op.operationId,{path,method,...op});pass("Every HTTP operation selected from served Swagger/OpenAPI");
 async function call(opId:string,id:string,token:string|null=creator,body?:any,status=200){const op=ops.get(opId);assert.ok(op,`Missing operation ${opId}`);const r=await fetch(base+op.path.replace(/\{\w+\}/g,id),{method:op.method.toUpperCase(),headers:{...(token?{Authorization:`Bearer ${token}`} : {}),...(body!==undefined?{"Content-Type":"application/json"}:{})},body:body!==undefined?JSON.stringify(body):undefined});const json:any=await r.json();assert.equal(r.status,status,`${opId}: ${JSON.stringify(json)}`);return json.data;}
 async function fixture(n=3){const o=await db.outings.create({data:{title:"Tie fixture",created_by:creator,group_id:group.id,status:"voting",scheduled_at:new Date(Date.now()+4*86400000),vote_ends_at:new Date(Date.now()+3600000)}});const options=[];for(let i=0;i<n;i++)options.push(await db.outing_vote_options.create({data:{outing_id:o.id,label:`Place ${i}`,sort_order:i}}));await db.outing_attendance.createMany({data:[{outing_id:o.id,user_id:creator,status:"going"},{outing_id:o.id,user_id:member,status:"maybe"}]});return {id:o.id,options};}
 const state=(id:string)=>call("getVotingState",id);const ballot=(id:string,uid:string,ids:string[],round=1,status=200)=>call("replaceOutingBallot",id,uid,{option_ids:ids,round_number:round},status);
 const legacy = await call("getVotingState", legacyOuting, "legacy-creator");
 assert.equal(legacy.voting_state, "confirmed");
 assert.equal(legacy.current_round.round_number, 1);
 assert.equal(legacy.confirmed_location.id, legacyOption);
 assert.equal(legacy.options[0].vote_count, 1);
 assert.deepEqual(legacy.my_option_ids, [legacyOption]);
 assert.equal(await db.outing_attendance.count({ where: { outing_id: legacyOuting, status: "going" } }), 1);
 pass("Pre-migration outing, winner, ballot and RSVP survive round-one backfill");
 const {closeDueVotingDeadlines}=await import("../src/jobs/close-voting-deadline.job.js");async function close(id:string){await db.outings.update({where:{id},data:{vote_ends_at:new Date(Date.now()-1000)}});await closeDueVotingDeadlines();return state(id);}
 await admin.query(`WITH singles AS (
   INSERT INTO outings (title, created_by, group_id, status, vote_ends_at)
   SELECT 'Single pending venue', $1, $2, 'voting', now() - interval '1 day' FROM generate_series(1, 51)
   RETURNING id
 ) INSERT INTO outing_vote_options (outing_id, label) SELECT id, 'Solo venue' FROM singles`, [creator, group.id]);
 const clear=await fixture();await ballot(clear.id,creator,[clear.options[0].id,clear.options[1].id]);await ballot(clear.id,member,[clear.options[0].id]);assert.equal((await close(clear.id)).outing.winning_option_id,clear.options[0].id);pass("Clear winner automatically confirmed; multiple location selection supported");
 assert.equal(await db.outings.count({ where: { title: "Single pending venue", vote_closed_at: null } }), 51);
 pass("Older single-venue outings do not block deadline processing");
 const two=await fixture();await ballot(two.id,creator,[two.options[0].id,two.options[1].id]);let tied=await close(two.id);assert.equal(tied.voting_state,"tie_pending");assert.equal(tied.tiedOptionIds.length,2);pass("Two-way top tie excludes lower location");
 await call("breakTie",two.id,member,{round_number:1},403);await call("breakTie",two.id,groupOwner,{round_number:1},403);pass("Member and noncreator group owner receive 403");await call("getVotingState",two.id,null,undefined,401);pass("Unauthenticated request rejected");
 const deadline=new Date(Date.now()+7200000).toISOString();
 assert.equal(tied.can_resolve_tie, true);
 assert.equal((await call("getVotingState", two.id, groupOwner)).can_resolve_tie, false);
 await call("startOutingRevote", two.id, groupOwner, { deadline }, 403);
 for (const operation of ["getVotingState", "breakTie", "startOutingRevote"]) {
   await call(operation, two.id, "legacy-creator", operation === "startOutingRevote" ? { deadline } : undefined, 404);
 }
 pass("Permission flag is creator-only and inaccessible voting resources return 404");
 const next=await call("startOutingRevote",two.id,creator,{deadline});assert.equal(next.voting_state,"revote_active");assert.equal(next.options.length,2);assert.equal(next.votes.length,0);assert.equal(next.current_round.round_number,2);assert.equal(await db.outing_votes.count({where:{outing_id:two.id,round_number:1}}),2);pass("Revote contains only tied locations, zero new votes and preserved history");
 await call("updateOuting", two.id, creator, { vote_ends_at: null }, 409);
 assert.equal((await state(two.id)).current_round.ends_at, next.current_round.ends_at);
 pass("Ordinary outing edits cannot clear a revote deadline");
 await call("startOutingRevote",two.id,creator,{deadline,round_number:1},409);await ballot(two.id,member,[two.options[2].id],2,400);await ballot(two.id,member,[two.options[0].id],1,409);pass("Duplicate revote, eliminated location and stale round rejected");
 await ballot(two.id,member,[two.options[0].id,two.options[1].id],2);await ballot(two.id,member,[two.options[0].id],2);await ballot(two.id,member,[],2);await ballot(two.id,member,[two.options[0].id,two.options[1].id],2);pass("Members can change and remove round selections");
 tied=await close(two.id);assert.equal(tied.voting_state,"tie_pending");assert.equal(tied.current_round.round_number,2);pass("Repeated tie awaits creator again");
 const [one,other]=await Promise.all([call("breakTie",two.id,creator,{round_number:2}),call("breakTie",two.id,creator,{round_number:2})]);assert.equal(one.winningOptionId,other.winningOptionId);assert.ok(tied.tiedOptionIds.includes(one.winningOptionId));assert.equal((await call("breakTie",two.id,creator,{round_number:2})).winningOptionId,one.winningOptionId);pass("Concurrent and repeated random requests return same persisted eligible winner");
 assert.deepEqual((await db.outing_attendance.findMany({where:{outing_id:two.id},orderBy:{user_id:"asc"}})).map((x:any)=>x.status),["going","maybe"]);pass("RSVP unchanged across closure, revote and random resolution");
 const zero=await fixture();tied=await close(zero.id);assert.equal(tied.tiedOptionIds.length,3);assert.equal(tied.outing.status,"voting");await call("breakTie",zero.id,creator,{round_number:1});pass("Zero votes retains all candidates for creator intervention");
 const three=await fixture(4);await ballot(three.id,creator,three.options.slice(0,3).map((o:any)=>o.id));tied=await close(three.id);assert.equal(tied.tiedOptionIds.length,3);pass("Three-way tie excludes lower candidate");
 const competing=await Promise.allSettled([call("breakTie",three.id,creator,{round_number:1}),call("startOutingRevote",three.id,creator,{deadline,round_number:1})]);assert.equal(competing.filter(r=>r.status==="fulfilled").length,1);pass("Random selection and revote race has one successful transition");
 const single=await fixture(1);assert.equal((await close(single.id)).isTied,false);await call("confirmOutingVenue",single.id,creator,{option_id:single.options[0].id});pass("Single venue retains creator confirmation workflow");
 const fixed = await db.outings.create({ data: { title: "Already pinned", created_by: creator, group_id: group.id, status: "confirmed", location_name: "Fixed venue" } });
 const fixedState = await state(fixed.id);
 assert.equal(fixedState.voting_state, "confirmed");
 assert.equal(fixedState.confirmed_location.label, "Fixed venue");
 assert.equal(fixedState.can_resolve_tie, false);
 pass("Already confirmed fixed venues are returned with no tie actions");
 const invalid=await fixture();await close(invalid.id);await call("startOutingRevote",invalid.id,creator,{deadline:new Date(Date.now()-10000).toISOString(),round_number:1},400);await db.outings.update({where:{id:invalid.id},data:{status:"cancelled"}});await call("breakTie",invalid.id,creator,{round_number:1},409);pass("Invalid deadline and cancelled outing rejected");

 const noVotesRevote=await fixture();await close(noVotesRevote.id);
 const emptyNext=await call("startOutingRevote",noVotesRevote.id,creator,{deadline,round_number:1});assert.equal(emptyNext.options.length,3);assert.equal(emptyNext.voted_count,0);pass("Zero-vote revote keeps all eligible candidates");
 await call("confirmOutingVenue",noVotesRevote.id,creator,{option_id:noVotesRevote.options[0].id},409);pass("Manual venue endpoint cannot bypass a revote");
 await call("removeMyVotes",noVotesRevote.id,member,undefined,409);pass("Legacy stale DELETE cannot remove current revote ballots");
 await db.users.create({data:{id:"tie-new-member",name:"New member",phone:"+15550008999"}});
 await db.outing_guests.create({data:{outing_id:noVotesRevote.id,user_id:"tie-new-member",status:"accepted"}});
 await ballot(noVotesRevote.id,"tie-new-member",[noVotesRevote.options[0].id],2);await ballot(noVotesRevote.id,"tie-new-member",[],2);pass("New accepted participant can vote after revote starts");
 const expiry=await fixture();await db.outings.update({where:{id:expiry.id},data:{vote_ends_at:new Date(Date.now()-1000)}});await ballot(expiry.id,member,[expiry.options[0].id],1,409);pass("Votes arriving after deadline are rejected before worker closure");
 await call("confirmOutingVenue", expiry.id, creator, { option_id: expiry.options[0].id }, 409);
 pass("Manual confirmation cannot bypass an expired competitive vote before the worker runs");
 const done=await fixture();await close(done.id);await db.outings.update({where:{id:done.id},data:{status:"past"}});await call("breakTie",done.id,creator,{round_number:1},409);pass("Completed outing cannot resolve a tie");
 await close(noVotesRevote.id);const thirdRound=await call("startOutingRevote",noVotesRevote.id,creator,{deadline,round_number:2});assert.equal(thirdRound.current_round.round_number,3);assert.equal(thirdRound.options.length,3);pass("Third voting round supported without carrying forward votes");
 const count=await db.notification_events.count({where:{outing_id:two.id}});await closeDueVotingDeadlines();await call("breakTie",two.id,creator,{round_number:2});assert.equal(await db.notification_events.count({where:{outing_id:two.id}}),count);pass("Retry creates no duplicate notification events");
 const prompts = await db.notifications.findMany({ where: { outing_id: two.id, OR: [
   { event_key: { startsWith: `voting_tie:${two.id}:2:` } },
   { event_key: { startsWith: `voting_tie_creator:${two.id}:2:` } },
 ] } });
 assert.deepEqual(prompts.filter((row: any) => row.action_required).map((row: any) => row.user_id), [creator]);
 assert.ok(prompts.some((row: any) => row.user_id === member && !row.action_required));
 assert.ok(prompts.every((row: any) => row.data.outingId === two.id && row.data.navigationSection === "voting"));
 for (const type of ["voting_started", "tie_break_selected", "outing_confirmed"]) {
   const event = await db.notification_events.findFirst({ where: { outing_id: two.id, recipient_user_id: member, type } });
   assert.equal(event?.payload.outingId, two.id);
 }
 pass("Creator and member notifications are persisted with correct actions and outing links");

 const {bindChatEmitter}=await import("../src/realtime/chat-emitter.js");
 const {userRealtimeRoom}=await import("../src/realtime/rooms.js");
 realtime = new SocketServer(server);
 realtime.use((connection, next) => next(connection.handshake.auth.token === member ? undefined : new Error("UNAUTHORIZED")));
 realtime.on("connection", connection => void connection.join(userRealtimeRoom(member)));
 bindChatEmitter(realtime);
 socket = socketClient(base, { auth: { token: member }, transports: ["websocket"] });
 await new Promise<void>((resolve, reject) => {
   socket!.once("connect", resolve);
   socket!.once("connect_error", reject);
 });
 const observed = await fixture();
 const events: Array<{ event: string; payload: any }> = [];
 socket.onAny((event, payload) => {
   if (event.startsWith("outing:") && payload.outingId === observed.id) events.push({ event, payload });
 });
 const observedTie = await close(observed.id);
 const observedRevote = await call("startOutingRevote", observed.id, creator, { deadline });
 await ballot(observed.id, member, [observed.options[0].id, observed.options[1].id], 2);
 const observedTieAgain = await close(observed.id);
 const observedWinner = await call("breakTie", observed.id, creator, { round_number: 2 });
 await call("breakTie", observed.id, creator, { round_number: 2 });
 assert.deepEqual(events.map(({event, payload}) => [event, payload.roundId, payload.votingState]), [
   ["outing:voting_tie_detected", observedTie.current_round.id, "tie_pending"],
   ["outing:voting_revote_started", observedRevote.current_round.id, "revote_active"],
   ["outing:voting_round_updated", observedRevote.current_round.id, "revote_active"],
   ["outing:voting_tie_detected", observedTieAgain.current_round.id, "tie_pending"],
   ["outing:location_confirmed", observedRevote.current_round.id, "confirmed"],
 ]);
 assert.deepEqual(new Set(events[1]!.payload.optionIds), new Set(observedRevote.options.map((option:any) => option.id)));
 assert.equal(events[4]!.payload.confirmedOptionId, observedWinner.winningOptionId);
 assert.ok(events.every(({payload}) => Number.isFinite(Date.parse(payload.updatedAt))));
 pass("Swagger mutations deliver consistent voting events to an authenticated fixture member, with one winner event on retry");
} catch(error) { console.error(error); throw error; } finally {
 socket?.disconnect();if(realtime)await realtime.close();else if(server)await new Promise<void>(r=>server.close(r));if(db)await db.$disconnect();await admin.query(`DROP SCHEMA IF EXISTS "${schema}" CASCADE`);await admin.end();await localServer?.stop();await localDb?.close();writeFileSync("../docs/audit/LOCATION_TIE_OPENAPI_RESULTS.json",JSON.stringify({checkedAt:new Date().toISOString(),engine:"Local PostgreSQL/WASM",mode:"Served Swagger HTTP, controlled authentication, deadline worker invoked directly and local Socket.IO delivery",results},null,2)+"\n");
}
