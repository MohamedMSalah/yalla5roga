import assert from "node:assert/strict";
import { createServer } from "node:http";
import { once } from "node:events";
import test from "node:test";
import { Server } from "socket.io";
import { io as connect } from "socket.io-client";
import { registerGroupGateway } from "../src/realtime/group.gateway.js";
import { groupRealtimeRoom } from "../src/realtime/rooms.js";

test("group rooms validate IDs and current membership on every join", { timeout: 5000 }, async (t) => {
  const http = createServer();
  const io = new Server(http);
  const groupId = "11111111-1111-4111-8111-111111111111";
  let member = true;
  io.use((socket, next) => { socket.data.uid = "alice"; next(); });
  registerGroupGateway(io, async (id, uid) => {
    assert.equal(id, groupId);
    assert.equal(uid, "alice");
    if (!member) throw new Error("removed");
    return {} as never;
  });
  http.listen(0, "127.0.0.1");
  await once(http, "listening");
  const address = http.address();
  assert.ok(address && typeof address !== "string");
  const client = connect(`http://127.0.0.1:${address.port}`, { transports: ["websocket"] });
  t.after(() => { client.close(); io.close(); });
  await once(client, "connect");
  assert.equal((await client.emitWithAck("group:join", { groupId: "bad" })).error, "INVALID_GROUP_ID");
  assert.equal((await client.emitWithAck("group:join", { groupId })).ok, true);
  assert.equal(io.sockets.sockets.get(client.id!)?.rooms.has(groupRealtimeRoom(groupId)), true);
  await client.emitWithAck("group:leave", { groupId });
  member = false;
  assert.equal((await client.emitWithAck("group:join", { groupId })).error, "FORBIDDEN");
  assert.equal(io.sockets.sockets.get(client.id!)?.rooms.has(groupRealtimeRoom(groupId)), false);
});
