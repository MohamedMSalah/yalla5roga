import "dotenv/config";
import assert from "node:assert/strict";
import { randomUUID, randomInt } from "node:crypto";
import { once } from "node:events";
import { it } from "node:test";
import express from "express";
import { prisma } from "../src/config/database.js";
import { GroupDatasource } from "../src/datasources/groups/group.datasource.js";
import { PrismaInvitationClaimStore } from "../src/datasources/groups/group-invitation.datasource.js";
import { GroupRepository } from "../src/repositories/groups/group.repository.js";
import type { IUserRepository } from "../src/repositories/users/i-user.repository.js";
import type { IGroupInvitationRepository } from "../src/repositories/groups/i-group-invitation.repository.js";
import { claimPendingInvitations } from "../src/services/groups/claim-pending-invitations.js";
import { NoopNotificationPublisher } from "../src/services/notifications/notification-publisher.js";
import { InviteToGroupUseCase } from "../src/usecases/groups/invite-to-group.usecase.js";
import { ClaimGroupInvitationsUseCase } from "../src/usecases/groups/claim-group-invitations.usecase.js";
import { SignupUseCase } from "../src/usecases/auth/signup.usecase.js";
import { LoginUseCase } from "../src/usecases/auth/login.usecase.js";
import { ListGroupsUseCase } from "../src/usecases/groups/list-groups.usecase.js";
import { GroupController } from "../src/controllers/groups/group.controller.js";
import { AuthController } from "../src/controllers/auth/auth.controller.js";
import { validate } from "../src/middleware/validate.middleware.js";
import { createAuthMiddleware } from "../src/middleware/auth.middleware.js";
import { errorMiddleware } from "../src/middleware/error.middleware.js";
import { signupBodySchema, loginBodySchema } from "../src/validators/auth/auth.validator.js";
import { inviteToGroupBodySchema } from "../src/validators/groups/group.validator.js";

// Real PostgreSQL queries, real controllers/use cases; Firebase proofs and
// sessions are injected. Every fixture write is inside one rolled-back txn.
it("HTTP invite -> signup/login -> PostgreSQL membership -> current-user groups", {
  skip: process.env.RUN_GROUP_DATABASE_TESTS !== "1",
  timeout: 90000,
}, async () => {
  const suffix = randomUUID();
  const owner = `group-test-owner-${suffix}`;
  const registered = `group-test-registered-${suffix}`;
  const future = `group-test-future-${suffix}`;
  const stranger = `group-test-stranger-${suffix}`;
  const phone = `+2010${randomInt(10000000, 99999999)}`;
  const futurePhone = `+2011${randomInt(10000000, 99999999)}`;
  const rollback = new Error("ROLLBACK_GROUP_MEMBERSHIP_FIXTURES");
  try {
    await assert.rejects(prisma.$transaction(async tx => {
      await tx.users.createMany({data:[
        {id:owner, name:"Test inviter", phone:`+2012${randomInt(10000000, 99999999)}`},
        {id:registered, name:"Registered B", phone},
        {id:stranger, name:"Unrelated", phone:`+2015${randomInt(10000000, 99999999)}`},
      ]});
      const groups = new GroupRepository(new GroupDatasource(tx));
      const group = await groups.create({name:"Membership regression", created_by:owner});
      assert.equal(group.member_count, 1);
      assert.equal((await groups.findMember(group.id, owner))?.role, "owner");
      const users = {
        findById:(id:string) => tx.users.findUnique({where:{id}}),
        findByPhone:(phone:string) => tx.users.findUnique({where:{phone}}),
        create:(data:never) => tx.users.create({data}),
      } as unknown as IUserRepository;
      const invitations = {
        findPending:(groupId:string, phone:string) => tx.group_invitations.findFirst({where:{group_id:groupId, invited_phone:phone, status:"pending"}}),
        createPending:async (data:never) => ({created:true, invitation:await tx.group_invitations.create({data})}),
        claimForVerifiedPhone:(userId:string, phone:string) => claimPendingInvitations(new PrismaInvitationClaimStore(tx), {userId,phone,now:new Date()}),
      } as unknown as IGroupInvitationRepository;
      const claims = new ClaimGroupInvitationsUseCase(invitations);
      const lookup = {findUserIdByVerifiedPhone:async (value:string) => value===phone ? registered : null};
      const invite = new InviteToGroupUseCase(groups,invitations,users,lookup,() => new Date(),new NoopNotificationPublisher(),() => false);
      const gc = new GroupController(undefined,undefined,new ListGroupsUseCase(groups),undefined,undefined,undefined,undefined,invite);
      const issueSession = async (uid:string) => ({uid,idToken:"test-id",customToken:"test-custom",refreshToken:"test-refresh",expiresIn:"3600"});
      const ac = new AuthController(
        new LoginUseCase(users,{verifiedPhone:async () => futurePhone},claims,issueSession),
        new SignupUseCase(users,{verifyProof:async () => ({uid:future,phone:futurePhone})},claims,issueSession),
      );
      const app = express(); app.use(express.json());
      app.post("/api/auth/signup",validate({body:signupBodySchema}),ac.signupHandler);
      app.post("/api/auth/login",validate({body:loginBodySchema}),ac.loginHandler);
      app.use(createAuthMiddleware(async token => ({uid:token}) as never));
      app.post("/api/groups/:id/invitations",validate({body:inviteToGroupBodySchema}),gc.invite);
      app.get("/api/groups/cuser",gc.listForCuser);
      app.use(errorMiddleware);
      const server = app.listen(0,"127.0.0.1"); await once(server,"listening");
      const address = server.address(); assert.ok(address && typeof address!=="string");
      const base = `http://127.0.0.1:${address.port}`;
      async function request(path:string, uid:string, body?:unknown) {
        const response = await fetch(base+path,{method:body ? "POST":"GET",headers:{authorization:`Bearer ${uid}`,"content-type":"application/json"},body:body ? JSON.stringify(body):undefined});
        return {status:response.status, body:await response.json() as any};
      }
      try {
        assert.equal((await request("/api/groups/cuser",registered)).body.data.length,0);
        const added = await request(`/api/groups/${group.id}/invitations`,owner,{phoneNumber:phone});
        assert.equal(added.status,201); assert.equal(added.body.data.outcome,"member_added");
        assert.equal(added.body.data.member.user_id,registered);
        assert.equal(added.body.data.member.group_id,group.id);
        const list = await request("/api/groups/cuser",registered);
        assert.equal(list.status,200); assert.equal(list.body.data[0].id,group.id); assert.equal(list.body.data[0].my_role,"member");
        assert.equal((await request("/api/groups/cuser",stranger)).body.data.length,0);
        assert.equal((await request(`/api/groups/${group.id}/invitations`,owner,{phoneNumber:phone})).body.data.outcome,"already_member");
        const pending = await request(`/api/groups/${group.id}/invitations`,owner,{phoneNumber:futurePhone});
        assert.equal(pending.body.data.outcome,"invited");
        const inviteId = pending.body.data.invitation_id;
        const before = await tx.group_invitations.findUniqueOrThrow({where:{id:inviteId}});
        assert.equal(before.user_id,null); assert.equal(before.invited_phone,futurePhone); assert.equal(before.group_id,group.id);
        const signup = await request("/api/auth/signup",future,{name:"Future B",phone:futurePhone,password:"secret123",phoneVerificationToken:"injected-verified-proof"});
        assert.equal(signup.status,201); assert.equal(signup.body.data.uid,future);
        const retry = await request("/api/auth/signup",future,{name:"Ignored retry name",phone:futurePhone,password:"secret123",phoneVerificationToken:"injected-verified-proof"});
        assert.equal(retry.status, 201);
        assert.equal(retry.body.data.user.name, "Future B");
        assert.equal(retry.body.data.user.has_password, true);
        assert.equal("password_hash" in retry.body.data.user, false);
        const after = await tx.group_invitations.findUniqueOrThrow({where:{id:inviteId}});
        assert.equal(after.status,"accepted"); assert.equal(after.user_id,future);
        assert.equal((await request("/api/groups/cuser",future)).body.data[0].id,group.id);
        assert.equal((await request("/api/auth/login",future,{phone:futurePhone,password:"secret123"})).status,200);
        assert.equal(await tx.group_members.count({where:{group_id:group.id,user_id:future}}),1);
        assert.equal(await tx.group_members.count({where:{group_id:group.id}}),3);
        const outing = await tx.outings.create({
          data: { title: "Integration plan", group_id: group.id, created_by: owner },
        });
        const guest = await tx.outing_guests.create({
          data: { outing_id: outing.id, user_id: future },
        });
        assert.equal(guest.status, "pending");
        const notification = await tx.notifications.create({
          data: { user_id: future, type: "system", body: "Integration fixture", outing_id: outing.id, group_id: group.id },
        });
        const stored = await tx.notifications.findUniqueOrThrow({ where: { id: notification.id } });
        assert.equal(stored.user_id, future);
        assert.equal(stored.outing_id, outing.id);
        console.log("Verified: immediate member, pending invite, signup claim, login, isolation, duplicate safety, FK IDs and group list.");
      } finally {server.closeAllConnections(); await new Promise<void>((resolve,reject) => server.close(error => error ? reject(error):resolve()));}
      throw rollback;
    },{timeout:80000,maxWait:10000}), error => error===rollback);
    assert.equal(await prisma.users.count({where:{id:{in:[owner,registered,future,stranger]}}}),0);
    console.log("Verified: transaction rolled back; no fixture accounts persisted.");
  } finally {await prisma.$disconnect();}
});
