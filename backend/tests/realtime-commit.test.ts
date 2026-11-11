import assert from "node:assert/strict";
import test from "node:test";
import type { Request, Response } from "express";
import type { Server } from "socket.io";
import { GroupController } from "../src/controllers/groups/group.controller.js";
import { bindChatEmitter } from "../src/realtime/chat-emitter.js";

test("group creation broadcasts only after successful persistence", async () => {
  const events: unknown[] = [];
  bindChatEmitter({ to: () => ({ emit: (_name: string, payload: unknown) => events.push(payload) }) } as unknown as Server);
  const request = { user: { uid: "alice" }, body: { name: "Friends" } } as unknown as Request;
  const response = { status: () => response, json: () => response } as unknown as Response;
  const failure = new Error("transaction rolled back");
  let caught: unknown;
  const rejected = new GroupController({ execute: async () => { throw failure; } } as never);
  await rejected.create(request, response, (error) => { caught = error; });
  assert.equal(caught, failure);
  assert.deepEqual(events, []);
  const committed = new GroupController({ execute: async () => {
    assert.equal(events.length, 0);
    return { id: "group" };
  } } as never);
  await committed.create(request, response, (error) => { throw error; });
  assert.equal(events.length, 1);
  assert.equal((events[0] as { kind: string }).kind, "group");
});
