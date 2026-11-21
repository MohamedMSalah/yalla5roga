import { isolatedDatabase } from "./support/isolated-database.js";
import assert from "node:assert/strict";
import { randomInt, randomUUID } from "node:crypto";
import { once } from "node:events";
import { test } from "node:test";
import { initializeApp, deleteApp } from "firebase-admin/app";
import { getAuth } from "firebase-admin/auth";
import { io as connect } from "socket.io-client";
import { responseAssertion, withApi, type OpenApi } from "./support/http-fixture.js";

const monitorToken = "local-workflow-monitoring-credential";
process.env.MONITORING_TOKEN = monitorToken;
process.env.OBSERVABILITY_ENABLED = "1";
process.env.OBS_MOBILE_TELEMETRY = "1";
const { default: app } = await import("../src/app.js");
const { prisma } = await import("../src/config/database.js");
const { attachRealtime } = await import("../src/realtime/index.js");
const { bindChatEmitter } = await import("../src/realtime/chat-emitter.js");

test("authenticated HTTP workflows, Prisma attribution and Socket.IO use a local fixture", {
  skip: !isolatedDatabase, timeout: 30000,
}, async t => {
  const suffix = randomUUID().slice(0, 12);
  const [owner, member, stranger] = ["owner", "member", "stranger"].map(role => `test-${role}-${suffix}`);
  const users = [owner!, member!, stranger!];
  const tokenToUser = new Map(users.map(id => [randomUUID(), id]));
  const userToToken = new Map([...tokenToUser].map(([token, id]) => [id, token]));
  const firebaseApp = initializeApp({ projectId: "demo-yalla-observability" });
  const auth = getAuth(firebaseApp);
  t.mock.method(auth, "verifyIdToken", async (token: string) => {
    const uid = tokenToUser.get(token);
    if (!uid) throw Object.assign(new Error("Invalid test credentials"), { code: "auth/invalid-id-token" });
    return { uid, firebase: { sign_in_provider: "custom" } };
  });
  const groups: string[] = [];
  const outings: string[] = [];

  try {
    await prisma.users.createMany({ data: users.map((id, index) =>
      ({ id, name: `Fixture ${index}`, phone: `+201${index}${randomInt(10000000, 99999999)}` })) });
    await withApi(app, async (base, server) => {
      const realtime = attachRealtime(server);
      const sockets: ReturnType<typeof connect>[] = [];
      const spec = await (await fetch(base + "/api-docs/openapi.json")).json() as OpenApi;
      const api = async (method: string, route: string, status: number, uid?: string, body?: unknown, path = route) => {
        const response = await fetch(base + path, {
          method, headers: { ...(uid ? { Authorization: `Bearer ${userToToken.get(uid)}` } : {}),
            "Content-Type": "application/json" },
          body: body === undefined ? undefined : JSON.stringify(body),
        });
        const payload = status === 204 ? null : await response.json() as any;
        assert.equal(response.status, status, `${method} ${route}`);
        if (payload) assert.equal(payload.success, response.ok);
        const operation = spec.paths[route]?.[method.toLowerCase()];
        if (operation) responseAssertion(spec, operation, status, response.headers.get("content-type")?.split(";")[0] ?? "", payload);
        return payload;
      };
      try {
        const created = await api("POST", "/api/groups", 201, owner, { name: "Observability local" });
        const group = created.data.id as string;
        groups.push(group);
        await prisma.group_members.create({ data: { group_id: group, user_id: member!, role: "member" } });
        const groupPath = `/api/groups/${group}`;
        assert.equal((await api("GET", "/api/groups/{id}", 200, owner, undefined, groupPath)).data.my_role, "owner");
        assert.equal((await api("GET", "/api/groups/{id}/members", 200, member, undefined, groupPath + "/members")).data.length, 2);
        await api("GET", "/api/groups/{id}", 403, stranger, undefined, groupPath);
        await api("PATCH", "/api/groups/{id}", 403, member, { name: "Denied" }, groupPath);
        assert.equal((await api("GET", "/api/groups/cuser", 200, member)).data[0].id, group);
        assert.equal((await api("GET", "/api/groups/cuser", 200, stranger)).data.length, 0);
        assert.equal((await api("POST", "/api/users/sync", 200, owner, {})).data.id, owner);
        assert.equal((await api("GET", "/api/users/cuser", 200, owner)).data.id, owner);
        await api("GET", "/api/outings/cuser", 200, owner);
        await api("GET", "/api/notifications", 200, owner, undefined, "/api/notifications?limit=1");
        await api("GET", "/api/notifications", 400, owner, undefined, "/api/notifications?limit=0");
        await api("GET", "/api/places", 200, undefined, undefined, "/api/places?limit=1&search=coffee");

        const scheduled = new Date(Date.now() + 4 * 3600000).toISOString();
        const outingBody = { title: "Observability outing", group_id: group, scheduled_at: scheduled, vote_deadline_hours: 2 };
        const outing = (await api("POST", "/api/outings", 201, owner, outingBody)).data.id as string;
        outings.push(outing);
        const outingPath = `/api/outings/${outing}`;
        await api("GET", "/api/outings/{id}", 200, member, undefined, outingPath);
        await api("GET", "/api/outings/{id}", 403, stranger, undefined, outingPath);
        const optionRoute = "/api/outings/{id}/vote-options";
        const optionPath = outingPath + "/vote-options";
        const first = (await api("POST", optionRoute, 201, owner, { label: "Option A" }, optionPath)).data.id;
        const second = (await api("POST", optionRoute, 201, owner, { label: "Option B" }, optionPath)).data.id;
        assert.notEqual(first, second);
        await api("POST", optionRoute, 403, member, { label: "Denied" }, optionPath);
        await api("GET", optionRoute, 200, member, undefined, optionPath);
        await api("GET", "/api/outings/{id}/voting-state", 200, member, undefined, outingPath + "/voting-state");
        await api("DELETE", "/api/outings/{id}/vote-options/{optionId}", 200, owner, undefined, optionPath + "/" + second);

        const messagesRoute = "/api/outings/{outingId}/messages";
        const messagesPath = outingPath + "/messages";
        const write = { text: "Synthetic idempotency fixture", clientMessageId: randomUUID() };
        const [a, b] = await Promise.all([
          api("POST", messagesRoute, 201, owner, write, messagesPath),
          api("POST", messagesRoute, 201, owner, write, messagesPath),
        ]);
        assert.equal(a.data.id, b.data.id);
        assert.equal(await prisma.chat_messages.count({ where: { outing_id: outing } }), 1);
        await api("GET", messagesRoute, 403, stranger, undefined, messagesPath);
        const page = await api("GET", messagesRoute, 200, member, undefined, messagesPath + "?limit=1");
        assert.equal(page.data[0].id, a.data.id);

        const withoutToken = connect(base, { transports: ["websocket"], reconnection: false });
        sockets.push(withoutToken);
        const [failure] = await once(withoutToken, "connect_error");
        assert.equal(failure.message, "UNAUTHORIZED");
        const client = connect(base, { transports: ["websocket"], reconnection: false, auth: { token: userToToken.get(member!) } });
        sockets.push(client);
        await once(client, "connect");
        const groupJoin = await client.timeout(3000).emitWithAck("group:join", { groupId: group });
        assert.equal(groupJoin.ok, true);
        const chatJoin = await client.timeout(3000).emitWithAck("outing:join", { outingId: outing });
        assert.equal(chatJoin.ok, true);
        assert.equal((await client.timeout(3000).emitWithAck("outing:leave", { outingId: outing })).ok, true);
        const socket = realtime.of("/").sockets.get(client.id!);
        assert.ok(socket && !socket.rooms.has(chatJoin.room));
        const disconnect = once(socket, "disconnect");
        client.disconnect();
        await disconnect;
        assert.ok(!realtime.of("/").adapter.rooms.has(groupJoin.room));

        const monitor = { Authorization: `Bearer ${monitorToken}` };
        const rows = [{ method: "GET", endpoint: "/api/groups/:id", clientMs: 10, serverMs: 4, status: 200 }];
        await api("POST", "/monitoring/mobile", 204, member, rows);
        await api("POST", "/monitoring/mobile", 400, member, [{ ...rows[0], endpoint: groupPath }]);
        const metrics = await (await fetch(base + "/metrics", { headers: monitor })).text();
        assert.match(metrics, /yalla_db_engine_query_seconds_count/);
        assert.match(metrics, /yalla_db_transaction_seconds_count/);
        assert.match(metrics, /yalla_socket_events_total.*event="group:join"/);
        assert.match(metrics, /yalla_mobile_duration_seconds_count.*endpoint="\/api\/groups\/:id"/);
        assert.ok(!metrics.includes(group) && !metrics.includes(outing) && !metrics.includes(owner!));
      } finally {
        for (const client of sockets) client.disconnect();
        await realtime.close();
        bindChatEmitter(null);
      }
    });
  } finally {
    await prisma.outings.deleteMany({ where: { id: { in: outings } } });
    await prisma.groups.deleteMany({ where: { id: { in: groups } } });
    await prisma.users.deleteMany({ where: { id: { in: users } } });
    await prisma.$disconnect();
    await deleteApp(firebaseApp);
  }
});
