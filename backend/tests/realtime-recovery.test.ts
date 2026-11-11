import assert from "node:assert/strict";
import test from "node:test";
import { emitDataChange, reconcileDataChanges } from "../src/realtime/data-changes.js";

test("reconciliation replays only missed changes authorized for this user", () => {
  const start = reconcileDataChanges("alice", null);
  assert.equal(start.reset, true);
  emitDataChange({ kind: "membership", id: "alice-group" }, ["alice"]);
  emitDataChange({ kind: "outing", id: "bob-outing" }, ["bob"]);
  emitDataChange({ kind: "outings", id: "shared" }, ["alice", "bob"]);
  const replay = reconcileDataChanges("alice", start.cursor);
  assert.equal(replay.reset, false);
  assert.deepEqual(replay.changes.map(({ cursor, ...change }) => change), [
    { kind: "membership", id: "alice-group" },
    { kind: "outings", id: "shared" },
  ]);
  assert.deepEqual(reconcileDataChanges("alice", replay.cursor).changes, []);
  assert.deepEqual(reconcileDataChanges("outsider", start.cursor).changes, []);
});

test("attendance replay carries only an authorized resource identifier, never historical roster data", () => {
  const start = reconcileDataChanges("alice", null);
  emitDataChange({ kind: "attendance", id: "outing", payload: {
    user_id: "bob", status: "going", updated_at: new Date().toISOString(),
  } }, ["alice"]);
  const [change] = reconcileDataChanges("alice", start.cursor).changes;
  assert.equal(change?.kind, "outing");
  assert.equal(change?.id, "outing");
  assert.equal("payload" in change!, false);
  assert.ok(change!.cursor.sequence > start.cursor.sequence);
});

test("restart, malformed, future and expired cursors require REST reset", () => {
  const initial = reconcileDataChanges("alice", null);
  for (const cursor of [null, {}, { epoch: "old", sequence: 0 },
    { ...initial.cursor, sequence: -1 },
    { ...initial.cursor, sequence: initial.cursor.sequence + 1 },
    { ...initial.cursor, sequence: 0.5 }]) {
    assert.equal(reconcileDataChanges("alice", cursor).reset, true);
  }
  for (let index = 0; index < 513; index++) {
    emitDataChange({ kind: "outing", id: `outing-${index}` }, ["alice"]);
  }
  const expired = reconcileDataChanges("alice", initial.cursor);
  assert.equal(expired.reset, true);
  assert.deepEqual(expired.changes, []);
});
