import assert from "node:assert/strict";
import { createServer } from "node:http";
import { once } from "node:events";
import test from "node:test";
import { Server } from "socket.io";
import { io as connect } from "socket.io-client";
import { bindChatEmitter, emitOutingMessage } from "../src/realtime/chat-emitter.js";
import { emitDataChange } from "../src/realtime/data-changes.js";
import { outingChatRoom, userRealtimeRoom } from "../src/realtime/rooms.js";

test("two signed-in users receive scoped changes; removed users lose chat delivery", { timeout: 5000 }, async (t) => {
  const http = createServer();
  const io = new Server(http);
  bindChatEmitter(io);
  t.after(() => io.close());
  // Fixture identities stand in for Firebase middleware. The production
  // emitter still uses the same authenticated rooms and socket user data.
  io.on("connection", (socket) => {
    const uid = String(socket.handshake.auth.uid);
    socket.data.uid = uid;
    void socket.join([userRealtimeRoom(uid), outingChatRoom("outing")]);
  });
  http.listen(0, "127.0.0.1");
  await once(http, "listening");
  const address = http.address();
  assert.ok(address && typeof address !== "string");
  const clients = ["alice", "bob", "outsider"].map((uid) =>
    connect(`http://127.0.0.1:${address.port}`, { auth: { uid }, transports: ["websocket"] }),
  );
  t.after(() => { clients.forEach((socket) => socket.close()); });
  await Promise.all(clients.map((socket) => once(socket, "connect")));

  for (const change of [
    { kind: "membership", id: "group" },
    { kind: "outings", id: "outing" },
    { kind: "outing", id: "outing" },
  ] as const) {
    const events = clients.slice(0, 2).map((socket) => once(socket, "data:changed"));
    const outsider = (payload: unknown) => assert.fail(`unscoped event ${JSON.stringify(payload)}`);
    clients[2]!.on("data:changed", outsider);
    emitDataChange(change, ["alice", "bob", "bob"]);
    for (const [event] of await Promise.all(events)) {
      assert.equal(event.kind, change.kind);
      assert.equal(event.id, change.id);
      if (event.cursor) {
        assert.equal(typeof event.cursor.epoch, "string");
        assert.ok(Number.isInteger(event.cursor.sequence));
      }
    }
    clients[2]!.off("data:changed", outsider);
  }

  const message = {
    id: "message", outing_id: "outing", sender_id: "alice", text: "Hello",
    sent_at: new Date(), sender: "Alice", avatar: null, client_message_id: "uuid",
  };
  const delivered = once(clients[0]!, "outing:message");
  let leaked = false;
  clients[1]!.on("outing:message", () => { leaked = true; });
  await emitOutingMessage("outing", message, ["alice"]);
  assert.equal((await delivered)[0].id, "message");
  // A follow-up broadcast on the same connections is a delivery barrier.
  const barrier = once(clients[1]!, "data:changed");
  emitDataChange({ kind: "inbox" }, ["bob"]);
  await barrier;
  assert.equal(leaked, false);
});

