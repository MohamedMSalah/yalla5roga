import { isolatedDatabase } from "./support/isolated-database.js";
import assert from "node:assert/strict";
import { randomInt, randomUUID } from "node:crypto";
import { once } from "node:events";
import { test } from "node:test";
import { deleteApp, initializeApp } from "firebase-admin/app";
import { getAuth } from "firebase-admin/auth";
import { io as connect } from "socket.io-client";
import { withApi, responseAssertion, type OpenApi } from "./support/http-fixture.js";
import { prisma } from "../src/config/database.js";
import { processAccountDeletions } from "../src/jobs/account-deletion.job.js";
import { attachRealtime } from "../src/realtime/socket-server.js";
import { bindChatEmitter } from "../src/realtime/chat-emitter.js";
import { recordAccountDeletion } from "../src/datasources/users/account-deletion.datasource.js";
import { accountDeletionKey, deletedAccountPlaceholder } from "../src/services/users/account-deletion-access.js";
import { MediaService } from "../src/services/media/media.service.js";

const { default: app } = await import("../src/app.js");

test("account deletion preserves shared history, transfers groups, and retries independent provider cleanup", {
  skip: !isolatedDatabase, timeout: 30_000,
}, async t => {
  const uid = `deletion-${randomUUID()}`;
  const other = `survivor-${randomUUID()}`;
  const phone = `+2010${randomInt(10000000, 99999999)}`;
  const otherPhone = `+2011${randomInt(10000000, 99999999)}`;
  const firebase = initializeApp({ projectId: "demo-yalla-delete" });
  const auth = getAuth(firebase);
  t.mock.method(auth, "verifyIdToken", async (token: string) => ({
    uid: token === "owner" ? uid : other,
    exp: Math.floor(Date.now() / 1000) + 60,
    firebase: { sign_in_provider: "custom" },
  }));
  const groups: string[] = [];
  const outings: string[] = [];
  try {
    await prisma.users.createMany({ data: [
      { id: uid, name: "Fixture deleted", phone, password_hash: "fixture" },
      { id: other, name: "Fixture retained", phone: otherPhone },
    ] });
    const [shared, solo, empty] = await Promise.all(["Shared", "History", "Empty"].map(name =>
      prisma.groups.create({ data: {
        name, created_by: uid, group_members: { create: { user_id: uid, role: "owner" } },
      } }),
    )) as [{ id: string }, { id: string }, { id: string }];
    groups.push(shared.id, solo.id, empty.id);
    await prisma.group_members.create({ data: { group_id: shared.id, user_id: other } });
    const sharedOuting = await prisma.outings.create({
      data: { group_id: shared.id, created_by: uid, title: "Shared fixture", status: "confirmed" },
    });
    const historyOuting = await prisma.outings.create({
      data: { group_id: solo.id, created_by: uid, title: "History fixture", status: "past" },
    });
    outings.push(sharedOuting.id, historyOuting.id);
    const deletedMessage = await prisma.chat_messages.create({
      data: { outing_id: sharedOuting.id, sender_id: uid, text: "Remove my message", client_message_id: randomUUID() },
    });
    const retainedMessage = await prisma.chat_messages.create({
      data: { outing_id: sharedOuting.id, sender_id: other, text: "Keep my message" },
    });
    const sharedInbox = await prisma.notifications.create({ data: {
      user_id: other, body: deletedMessage.text,
      data: { messageId: deletedMessage.id, senderId: uid, senderName: "Fixture deleted", body: deletedMessage.text },
    } });
    await prisma.outing_attendance.createMany({ data: [
      { outing_id: sharedOuting.id, user_id: uid, status: "going" },
      { outing_id: sharedOuting.id, user_id: other, status: "maybe" },
    ] });
    const invitation = await prisma.group_invitations.create({
      data: {
        group_id: shared.id, invited_by_user_id: other, invited_phone: phone, user_id: uid, status: "accepted",
        expires_at: new Date(Date.now() + 3600_000),
      },
    });
    const retainedInvite = await prisma.group_invitations.create({
      data: {
        group_id: shared.id, invited_by_user_id: uid, invited_phone: otherPhone, user_id: other, status: "accepted",
        expires_at: new Date(Date.now() + 3600_000),
      },
    });
    await prisma.notification_events.create({
      data: { type: "group_invite", recipient_user_id: uid, invitation_id: invitation.id, payload: {} },
    });
    const objectKey = `profiles/fixture/${randomUUID()}.png`;
    const asset = await prisma.media_assets.create({
      data: {
        object_key: objectKey, bucket: "mock-bucket", mime_type: "image/png", file_size: 1,
        purpose: "profile", owner_id: uid, status: "ready",
      },
    });
    await prisma.users.update({ where: { id: uid }, data: { image_url: `media://${asset.id}` } });

    await withApi(app, async (base, server) => {
      const io = attachRealtime(server);
      const client = connect(base, { transports: ["websocket"], reconnection: false, auth: { token: "owner" } });
      const http = (path: string, token: string, method = "DELETE") =>
        fetch(base + path, { method, headers: { Authorization: `Bearer ${token}` } });
      try {
        await once(client, "connect");
        assert.equal((await http(`/api/users/${uid}`, "other")).status, 403);
        const disconnected = once(client, "disconnect");
        const response = await http("/api/users/cuser", "owner");
        assert.equal(response.status, 202);
        const spec = await (await fetch(base + "/api-docs/openapi.json")).json() as OpenApi;
        responseAssertion(spec, spec.paths["/api/users/cuser"]!.delete!, 202, "application/json", await response.json());
        await disconnected;
        assert.equal((await http("/api/users/cuser", "owner", "GET")).status, 401);
        assert.equal((await http("/api/users/cuser", "other", "GET")).status, 200);
      } finally {
        client.disconnect();
        await io.close();
        bindChatEmitter(null);
      }
    });

    const { accountKey } = await recordAccountDeletion(uid);
    assert.equal(await prisma.users.findUnique({ where: { id: uid } }), null);
    await assert.rejects(prisma.users.create({ data: { id: uid, name: "Replay", phone } }));
    assert.equal((await prisma.groups.findUniqueOrThrow({ where: { id: shared.id } })).created_by, other);
    assert.equal((await prisma.group_members.findUniqueOrThrow({
      where: { group_id_user_id: { group_id: shared.id, user_id: other } },
    })).role, "owner");
    assert.equal((await prisma.groups.findUniqueOrThrow({ where: { id: solo.id } })).created_by, deletedAccountPlaceholder);
    assert.equal(await prisma.groups.findUnique({ where: { id: empty.id } }), null);
    assert.equal((await prisma.outings.findUniqueOrThrow({ where: { id: sharedOuting.id } })).status, "cancelled");
    assert.equal((await prisma.outings.findUniqueOrThrow({ where: { id: historyOuting.id } })).status, "past");
    const redacted = await prisma.chat_messages.findUniqueOrThrow({ where: { id: deletedMessage.id } });
    assert.equal(redacted.text, "");
    assert.equal(redacted.sender_id, deletedAccountPlaceholder);
    assert.equal((await prisma.chat_messages.findUniqueOrThrow({ where: { id: retainedMessage.id } })).text, "Keep my message");
    const redactedInbox = await prisma.notifications.findUniqueOrThrow({ where: { id: sharedInbox.id } });
    assert.equal(redactedInbox.body, "Message removed");
    assert.equal(JSON.stringify(redactedInbox.data).includes(uid), false);
    assert.equal(await prisma.outing_attendance.count({ where: { outing_id: sharedOuting.id } }), 1);
    assert.equal(await prisma.group_invitations.findUnique({ where: { id: invitation.id } }), null);
    assert.equal((await prisma.group_invitations.findUniqueOrThrow({ where: { id: retainedInvite.id } })).invited_by_user_id,
      deletedAccountPlaceholder);
    assert.equal(await prisma.notification_events.count({ where: { recipient_user_id: uid } }), 0);
    assert.equal(await prisma.media_assets.findUnique({ where: { id: asset.id } }), null);
    const queued = await prisma.account_deletion_media.findFirstOrThrow({ where: { account_key: accountKey } });
    assert.ok(queued.purge_after.getTime() > Date.now());
    const media = new MediaService();
    const purge = t.mock.method(media, "purgeObject", async () => {});
    await assert.rejects(processAccountDeletions({
      disable: async () => { throw new Error("Firebase offline"); },
      delete: async () => assert.fail("Identity cannot be deleted before disabling"),
    }, media));
    assert.equal(purge.mock.callCount(), 0);
    assert.equal((await prisma.account_deletions.findUniqueOrThrow({ where: { account_key: accountKey } })).firebase_uid, uid);
    const retryNow = async () => {
      await prisma.account_deletions.update({ where: { account_key: accountKey }, data: { retry_after: new Date(0) } });
      await prisma.account_deletion_media.updateMany({ where: { account_key: accountKey }, data: { purge_after: new Date(0) } });
    };
    const disable = t.mock.fn(async () => {});
    await prisma.account_deletions.update({ where: { account_key: accountKey }, data: { retry_after: new Date(0) } });
    await processAccountDeletions({
      disable, delete: async () => assert.fail("Outstanding custom tokens may be valid"),
    }, media);
    assert.equal(disable.mock.callCount(), 1);
    assert.ok((await prisma.account_deletions.findUniqueOrThrow({ where: { account_key: accountKey } })).firebase_disabled_at);
    await prisma.account_deletions.update({ where: { account_key: accountKey }, data: { requested_at: new Date(0) } });
    await retryNow();
    purge.mock.mockImplementationOnce(async () => { throw new Error("R2 offline"); });
    const removeIdentity = {
      disable: async () => assert.fail("Firebase identity already disabled"),
      delete: async () => { throw Object.assign(new Error("Already removed"), { code: "auth/user-not-found" }); },
    };
    await assert.rejects(processAccountDeletions(removeIdentity, media));
    const pending = await prisma.account_deletions.findUniqueOrThrow({ where: { account_key: accountKey } });
    assert.equal(pending.firebase_uid, null);
    assert.equal(pending.completed_at, null);
    await retryNow();
    await processAccountDeletions({
      disable: removeIdentity.disable, delete: async () => assert.fail("Firebase cleanup already completed"),
    }, media);
    assert.equal(purge.mock.callCount(), 2);
    assert.equal(await prisma.account_deletion_media.count({ where: { account_key: accountKey } }), 0);
    assert.ok((await prisma.account_deletions.findUniqueOrThrow({ where: { account_key: accountKey } })).completed_at);
  } finally {
    await prisma.notification_events.deleteMany({ where: { recipient_user_id: uid } });
    await prisma.outings.deleteMany({ where: { id: { in: outings } } });
    await prisma.groups.deleteMany({ where: { id: { in: groups } } });
    await prisma.users.deleteMany({ where: { id: { in: [uid, other] } } });
    await prisma.account_deletions.deleteMany({ where: { account_key: accountDeletionKey(uid) } });
    await deleteApp(firebase);
    await prisma.$disconnect();
  }
});
