/** API integration only. Real isolated Neon schema, bcrypt and Express; controlled Firebase SDK boundary. */
import "dotenv/config";
import assert from "node:assert/strict";
import { test } from "node:test";
import { randomUUID } from "node:crypto";
import { readFileSync } from "node:fs";
import { Client } from "pg";
import express from "express";
import type { Auth, DecodedIdToken, UserRecord } from "firebase-admin/auth";

await test("password recovery HTTP/OpenAPI integration", {
  skip: process.env.RUN_RECOVERY_API_TESTS !== "1", timeout:120000,
}, async t => {
  const schema = `recovery_api_${randomUUID().replaceAll("-", "")}`;
  const url = new URL(process.env.DATABASE_URL!);
  process.env.NODE_ENV="test";
  url.searchParams.set("sslmode","verify-full");
  url.searchParams.delete("channel_binding"); url.searchParams.delete("pgbouncer");
  url.hostname = url.hostname.replace("-pooler.", ".");
  const admin = new Client({connectionString:url.toString(),ssl:{rejectUnauthorized:true},connectionTimeoutMillis:15000});
  url.searchParams.set("schema",schema); process.env.DATABASE_URL=url.toString();
  await admin.connect();
  let prisma: import("@prisma/client").PrismaClient | undefined;
  let server: import("node:http").Server | undefined;
  try {
    await admin.query(`CREATE SCHEMA "${schema}"`);
    await admin.query(`SET search_path TO "${schema}"`);
    await admin.query(`CREATE TABLE users (id VARCHAR(128) PRIMARY KEY,name VARCHAR(30) NOT NULL,
      phone VARCHAR(16) UNIQUE NOT NULL,password_hash VARCHAR(255),image_url VARCHAR(2048),
      created_at TIMESTAMPTZ NOT NULL DEFAULT now(),updated_at TIMESTAMPTZ NOT NULL DEFAULT now())`);
    await admin.query(readFileSync(new URL("../prisma/migrations/20261111180000_password_recovery/migration.sql",import.meta.url),"utf8"));
    prisma=(await import("../src/config/database.js")).prisma;
    const {PasswordRecoveryUseCase}=await import("../src/usecases/auth/password-recovery.usecase.js");
    const {PasswordRecoveryRepository}=await import("../src/repositories/auth/password-recovery.repository.js");
    const {UserRepository}=await import("../src/repositories/users/user.repository.js");
    const {FirebasePhoneIdentity}=await import("../src/services/phone/phone-identity.js");
    const {LoginUseCase}=await import("../src/usecases/auth/login.usecase.js");
    const {SignupUseCase}=await import("../src/usecases/auth/signup.usecase.js");
    const {AuthController}=await import("../src/controllers/auth/auth.controller.js");
    const {createAuthRouter}=await import("../src/routes/auth/index.js");
    const {swaggerSpec}=await import("../src/config/swagger.js");
    const {errorMiddleware}=await import("../src/middleware/error.middleware.js");
    const {hashPassword}=await import("../src/services/auth/password.js");
    let now=Date.now();
    const phone="+201001234567", uid="recovery-existing-uid", otherPhone="+201112345678", otherUid="other-existing-uid";
    const records=new Map([[uid,phone],[otherUid,otherPhone]]);
    const proofs=new Map<string,DecodedIdToken>();
    let checkedRevocation=false;
    const firebase={
      verifyIdToken:async (token:string,revoked:boolean)=>{
        checkedRevocation=revoked;
        if(!proofs.has(token)) throw Error("auth/invalid-or-expired-token");
        return proofs.get(token)!;
      },
      getUser:async (id:string)=>({uid:id,phoneNumber:records.get(id),disabled:false}) as UserRecord,
    } as unknown as Pick<Auth,"verifyIdToken"|"getUser"|"updateUser">;
    const phones=new FirebasePhoneIdentity(()=>firebase,()=>now);
    const users=new UserRepository(), store=new PasswordRecoveryRepository();
    const recovery=new PasswordRecoveryUseCase(store,users,phones,()=>now);
    const login=new LoginUseCase(users,phones,{execute:async()=>[]},async uid=>({
      uid,idToken:"fixture-id",refreshToken:"fixture-refresh",expiresIn:"3600",customToken:"fixture-custom",
    }));
    const app=express(); app.use(express.json());
    const signup=new SignupUseCase(users,phones,{execute:async()=>[]},async uid=>({
      uid,idToken:"fixture-id",refreshToken:"fixture-refresh",expiresIn:"3600",customToken:"fixture-custom",
    }));
    app.use(createAuthRouter(new AuthController(login,signup,undefined,undefined,recovery))); app.use(errorMiddleware);
    server=app.listen(0,"127.0.0.1");
    await new Promise<void>(resolve=>server!.once("listening",resolve));
    const base=`http://127.0.0.1:${(server.address() as import("node:net").AddressInfo).port}`;
    const paths=(swaggerSpec as {paths:Record<string,{post?:{operationId:string}}>}).paths;
    function path(id:string){const entry=Object.entries(paths).find(([,p])=>p.post?.operationId===id); assert.ok(entry,id); return entry[0];}
    async function call(id:string,body:unknown,expected=200){
      const r=await fetch(base+path(id),{method:"POST",headers:{"Content-Type":"application/json"},body:JSON.stringify(body)});
      const json=await r.json() as {success:boolean;data:Record<string,any>;message?:string};
      assert.equal(r.status,expected,`${id}: ${json.message??""}`); assert.equal(json.success,expected===200 || expected===201);
      if(id!=="loginWithPhonePassword" && id!=="signupWithPhonePassword") assert.equal(r.headers.get("cache-control"),"no-store");
      return json.data;
    }
    async function clear(){await prisma!.password_recoveries.deleteMany();await prisma!.password_recovery_limits.deleteMany();}
    function proof(name="fresh",patch:Record<string,unknown>={}){
      proofs.set(name,{uid,phone_number:phone,auth_time:Math.floor(now/1000),firebase:{sign_in_provider:"phone"},...patch} as DecodedIdToken);
      return name;
    }
    const start=()=>call("startPasswordRecovery",{phone});
    const verify=(requestToken:string,token=proof(),status=200)=>call("verifyPasswordRecovery",{requestToken,phoneVerificationToken:token},status);
    const reset=(resetToken:string,password="NewPass2!",confirmation=password,status=200)=>call("resetRecoveredPassword",{resetToken,newPassword:password,confirmPassword:confirmation},status);
    async function authorize(){const c=await start(); now+=2000; return verify(c.requestToken);}
    await prisma.users.createMany({data:[{id:uid,name:"Original profile",phone,password_hash:await hashPassword("OldPass1!")},
      {id:otherUid,name:"Other",phone:otherPhone,password_hash:await hashPassword("OtherPass1!")}]});

    await t.test("successful recovery preserves UID/profile; new password logs in; old password and replay fail",async()=>{
      const g=await authorize(); assert.equal(checkedRevocation,true);
      const stored=await prisma!.password_recoveries.findFirstOrThrow();
      assert.match(stored.reset_hash!,/^[a-f0-9]{64}$/);assert.notEqual(stored.reset_hash,g.resetToken);
      await reset(g.resetToken);
      assert.equal((await call("loginWithPhonePassword",{phone,password:"NewPass2!"})).uid,uid);
      await call("loginWithPhonePassword",{phone,password:"OldPass1!"},401);
      assert.equal(await prisma!.users.count(),2);assert.equal((await users.findById(uid))!.name,"Original profile");
      await reset(g.resetToken,"AgainPass3!","AgainPass3!",401);
    });
    await t.test("incorrect/expired OTP proof and custom-session proof cannot authorize",async()=>{
      await clear();const c=await start();now+=2000;
      for(const token of ["invalid-otp","expired-token",proof("old",{auth_time:Math.floor(now/1000)-601}),proof("custom",{firebase:{sign_in_provider:"custom"}})])
        await verify(c.requestToken,token,401);
    });
    await t.test("wrong phone/UID, pre-challenge sign-in and client verification flags fail",async()=>{
      await clear();const c=await start();now+=2000;
      for(const token of [proof("wrong",{uid:otherUid,phone_number:otherPhone}),proof("uid",{uid:otherUid}),proof("before",{auth_time:Math.floor(now/1000)-60})])
        await verify(c.requestToken,token,401);
      await call("verifyPasswordRecovery",{requestToken:c.requestToken,phoneVerificationToken:proof(),verified:true,phone},400);
    });
    await t.test("unregistered and unbound legacy phones fail without creating users",async()=>{
      await clear();await call("startPasswordRecovery",{phone:"+201223456789"},400);
      records.delete(uid);await call("startPasswordRecovery",{phone},400);records.set(uid,phone);
      assert.equal(await prisma!.users.count(),2);
    });
    await t.test("weak, UTF-8 oversized and mismatched passwords leave the grant usable",async()=>{
      await clear();const g=await authorize();
      for(const [p,c] of [["abc","abc"],["alllowercase","alllowercase"],["PassWord1!","different"],["Aa1!"+"\u{1F600}".repeat(20),"Aa1!"+"\u{1F600}".repeat(20)]])
        await reset(g.resetToken,p,c,400);
      await reset(g.resetToken,"ValidPass3!");
    });
    await t.test("expired challenge and reset authorization fail",async()=>{
      await clear();const c=await start();now+=600001;await verify(c.requestToken,proof(),401);
      await clear();const g=await authorize();now+=300001;await reset(g.resetToken,"NextPass4!","NextPass4!",401);
    });
    await t.test("same phone sign-in cannot mint another grant even through refreshed proof",async()=>{
      await clear();const a=await start();now+=61000;const b=await start();now+=2000;
      await verify(a.requestToken);await verify(a.requestToken,proof(),401);await verify(b.requestToken,proof("refreshed"),401);
    });
    await t.test("resend cooldown, per-phone limit and proof guessing limits persist",async()=>{
      await clear();await start();await call("startPasswordRecovery",{phone},429);
      for(let i=0;i<3;i++){now+=61000;await start();}now+=61000;await call("startPasswordRecovery",{phone},429);
      await clear();const c=await start();
      for(let i=0;i<5;i++)await verify(c.requestToken,"bad",401);
      await verify(c.requestToken,proof(),429);
    });
    await t.test("parallel reset requests consume the authorization once",async()=>{
      await clear();const g=await authorize();
      const statuses=await Promise.all([1,2].map(async n=>{
        const p=`ParallelPass${n}!`;
        const r=await fetch(base+path("resetRecoveredPassword"),{method:"POST",headers:{"Content-Type":"application/json"},body:JSON.stringify({resetToken:g.resetToken,newPassword:p,confirmPassword:p})});
        await r.json();return r.status;
      }));assert.deepEqual(statuses.sort(),[200,401]);
    });
    await t.test("account phone or password changes invalidate earlier authorization",async()=>{
      await clear();const g=await authorize();await prisma!.users.update({where:{id:uid},data:{password_hash:await hashPassword("ChangedPass5!")}});
      await reset(g.resetToken,"AttackPass6!","AttackPass6!",400);
      await clear();const h=await authorize();records.set(uid,otherPhone);
      await reset(h.resetToken,"AttackPass6!","AttackPass6!",400);records.set(uid,phone);
    });
    await t.test("existing OTP signup still retains the verified UID and permits password login",async()=>{
      await clear();
      const newUid="signup-regression-uid",newPhone="+201223456789";
      records.set(newUid,newPhone);
      const token=proof("signup-proof",{uid:newUid,phone_number:newPhone});
      const created=await call("signupWithPhonePassword",{name:"New signup",phone:newPhone,password:"SignupPass7!",phoneVerificationToken:token},201);
      assert.equal(created.uid,newUid);
      assert.equal((await call("loginWithPhonePassword",{phone:newPhone,password:"SignupPass7!"})).uid,newUid);
      await prisma!.users.delete({where:{id:newUid}}); records.delete(newUid);
    });
    await t.test("per-IP API attempts are rate limited",async()=>{
      await clear();for(let i=0;i<30;i++)await call("startPasswordRecovery",{},400);await call("startPasswordRecovery",{},429);
    });
  } finally {
    if(server)await new Promise<void>((resolve,reject)=>server!.close(error=>error?reject(error):resolve()));
    await prisma?.$disconnect();
    await admin.query(`DROP SCHEMA IF EXISTS "${schema}" CASCADE`);await admin.end();
  }
});
