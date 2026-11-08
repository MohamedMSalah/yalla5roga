/**
 * Outing chat real-time audit probe (hybrid REST + Socket.IO).
 * Marks realtime PASS only when B receives A's message over the socket
 * without an extra REST GET.
 */
import "dotenv/config";
import fs from "node:fs";
import { io, type Socket } from "socket.io-client";
import { prisma } from "../src/config/database.js";
import { getFirebaseAuth } from "../src/config/firebase.js";

const UID_A = "chat-rt-audit-a";
const UID_B = "chat-rt-audit-b";
const UID_STRANGER = "chat-rt-audit-stranger";

const flutterEnv = fs.readFileSync("../flutter/.env", "utf8");
const apiKey = flutterEnv
  .split(/\r?\n/)
  .find((line) => line.startsWith("FIREBASE_ANDROID_API_KEY="))
  ?.split("=")[1]
  ?.trim();
if (!apiKey) throw new Error("missing FIREBASE_ANDROID_API_KEY in flutter/.env");

const base = "http://127.0.0.1:3000";
const auth = getFirebaseAuth();

type Hit = { scenario: string; ok: boolean; detail: string };
const results: Hit[] = [];

function record(scenario: string, ok: boolean, detail: string) {
  results.push({ scenario, ok, detail });
  console.log(`${ok ? "PASS" : "FAIL"}  ${scenario} — ${detail}`);
}

async function idTokenFor(uid: string): Promise<string> {
  const customToken = await auth.createCustomToken(uid);
  const exchange = await fetch(
    `https://identitytoolkit.googleapis.com/v1/accounts:signInWithCustomToken?key=${apiKey}`,
    {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ token: customToken, returnSecureToken: true }),
    },
  );
  const body = (await exchange.json()) as { idToken?: string };
  if (!body.idToken) {
    throw new Error(`Firebase ID token exchange failed for ${uid}`);
  }
  return body.idToken;
}

async function api(
  token: string,
  method: string,
  path: string,
  body?: Record<string, unknown>,
) {
  const response = await fetch(base + path, {
    method,
    headers: {
      Authorization: `Bearer ${token}`,
      "Content-Type": "application/json",
    },
    body: body ? JSON.stringify(body) : undefined,
  });
  const text = await response.text();
  let data: unknown = text;
  try {
    data = JSON.parse(text);
  } catch {
    // keep text
  }
  return { status: response.status, data };
}

function dataOf<T>(payload: unknown): T | undefined {
  if (payload && typeof payload === "object" && "data" in payload) {
    return (payload as { data?: T }).data;
  }
  return undefined;
}

function connectSocket(token: string): Promise<Socket> {
  return new Promise((resolve, reject) => {
    const socket = io(base, {
      path: "/socket.io",
      transports: ["websocket"],
      auth: { token },
      autoConnect: false,
      reconnection: false,
    });
    const timer = setTimeout(() => {
      socket.close();
      reject(new Error("socket connect timeout"));
    }, 8000);
    socket.on("connect", () => {
      clearTimeout(timer);
      resolve(socket);
    });
    socket.on("connect_error", (err) => {
      clearTimeout(timer);
      reject(err);
    });
    socket.connect();
  });
}

function joinOuting(
  socket: Socket,
  outingId: string,
): Promise<{ ok: boolean; error?: string; room?: string }> {
  return new Promise((resolve) => {
    socket
      .timeout(8000)
      .emit("outing:join", { outingId }, (err: Error | null, ack: unknown) => {
        if (err) {
          resolve({ ok: false, error: err.message });
          return;
        }
        const payload =
          ack && typeof ack === "object"
            ? (ack as { ok?: boolean; error?: string; room?: string })
            : {};
        resolve({
          ok: payload.ok === true,
          error: payload.error,
          room: payload.room,
        });
      });
  });
}

function waitForMessage(
  socket: Socket,
  predicate: (msg: Record<string, unknown>) => boolean,
  timeoutMs = 8000,
): Promise<Record<string, unknown>> {
  return new Promise((resolve, reject) => {
    const timer = setTimeout(() => {
      socket.off("outing:message", handler);
      reject(new Error("timeout waiting for outing:message"));
    }, timeoutMs);
    function handler(payload: unknown) {
      if (!payload || typeof payload !== "object") return;
      const msg = payload as Record<string, unknown>;
      if (!predicate(msg)) return;
      clearTimeout(timer);
      socket.off("outing:message", handler);
      resolve(msg);
    }
    socket.on("outing:message", handler);
  });
}

const tokenA = await idTokenFor(UID_A);
const tokenB = await idTokenFor(UID_B);
const tokenStranger = await idTokenFor(UID_STRANGER);

await api(tokenA, "POST", "/api/users/sync", {});
await api(tokenB, "POST", "/api/users/sync", {});
await api(tokenStranger, "POST", "/api/users/sync", {});

const group = await api(tokenA, "POST", "/api/groups", {
  name: "Chat RT Audit",
  bio: "realtime audit",
});
const groupId = dataOf<{ id?: string }>(group.data)?.id;
if (!groupId) {
  record("setup.group", false, `status=${group.status}`);
  console.log(JSON.stringify(results, null, 2));
  process.exit(1);
}
record("setup.group", true, groupId);

await prisma.group_members.upsert({
  where: { group_id_user_id: { group_id: groupId, user_id: UID_B } },
  create: { group_id: groupId, user_id: UID_B, role: "member" },
  update: {},
});
record("setup.addMemberB", true, UID_B);

const deadline = new Date(Date.now() + 3 * 60 * 60 * 1000).toISOString();
const outing = await api(tokenA, "POST", "/api/outings", {
  title: "Chat RT Outing",
  group_id: groupId,
  status: "draft",
  occasion: "none",
  vote_deadline_hours: 3,
  vote_ends_at: deadline,
});
const outingId = dataOf<{ id?: string }>(outing.data)?.id;
if (!outingId) {
  record("setup.outing", false, `status=${outing.status}`);
  process.exit(1);
}
record("setup.outing", true, outingId);

// --- Socket auth ---
let socketA: Socket | undefined;
let socketB: Socket | undefined;
let socketStranger: Socket | undefined;

try {
  socketA = await connectSocket(tokenA);
  record("socket.A.connect", true, socketA.id ?? "connected");
} catch (error) {
  record(
    "socket.A.connect",
    false,
    error instanceof Error ? error.message : String(error),
  );
}

try {
  socketB = await connectSocket(tokenB);
  record("socket.B.connect", true, socketB.id ?? "connected");
} catch (error) {
  record(
    "socket.B.connect",
    false,
    error instanceof Error ? error.message : String(error),
  );
}

try {
  const bad = io(base, {
    path: "/socket.io",
    transports: ["websocket"],
    auth: { token: "not-a-firebase-token" },
    autoConnect: false,
    reconnection: false,
  });
  const rejected = await new Promise<boolean>((resolve) => {
    const timer = setTimeout(() => {
      bad.close();
      resolve(false);
    }, 5000);
    bad.on("connect", () => {
      clearTimeout(timer);
      bad.close();
      resolve(false);
    });
    bad.on("connect_error", () => {
      clearTimeout(timer);
      bad.close();
      resolve(true);
    });
    bad.connect();
  });
  record(
    "security.invalidTokenRejected",
    rejected,
    rejected ? "connect_error as expected" : "unexpectedly connected",
  );
} catch (error) {
  record(
    "security.invalidTokenRejected",
    true,
    error instanceof Error ? error.message : "rejected",
  );
}

if (socketA && socketB) {
  const joinA = await joinOuting(socketA, outingId);
  record(
    "socket.A.join",
    joinA.ok === true && joinA.room === `outing:${outingId}`,
    JSON.stringify(joinA),
  );
  const joinB = await joinOuting(socketB, outingId);
  record(
    "socket.B.join",
    joinB.ok === true && joinB.room === `outing:${outingId}`,
    JSON.stringify(joinB),
  );

  // Unauthorized cannot join
  try {
    socketStranger = await connectSocket(tokenStranger);
    const joinS = await joinOuting(socketStranger, outingId);
    record(
      "security.strangerJoinForbidden",
      joinS.ok === false && joinS.error === "FORBIDDEN",
      JSON.stringify(joinS),
    );
  } catch (error) {
    record(
      "security.strangerJoinForbidden",
      false,
      error instanceof Error ? error.message : String(error),
    );
  }

  // Real-time: B listens BEFORE A posts via REST
  const pendingB = waitForMessage(
    socketB,
    (msg) => msg.text === "hello from A realtime",
  );
  const sendA = await api(tokenA, "POST", `/api/outings/${outingId}/messages`, {
    text: "hello from A realtime",
  });
  const msgA = dataOf<{ id?: string; sender_id?: string }>(sendA.data);
  record(
    "rest.A.send",
    sendA.status === 201 && msgA?.sender_id === UID_A,
    `status=${sendA.status} id=${msgA?.id ?? "n/a"}`,
  );

  let socketMsgA: Record<string, unknown> | undefined;
  try {
    socketMsgA = await pendingB;
    record(
      "realtime.B.receivesA",
      socketMsgA.id === msgA?.id && socketMsgA.sender_id === UID_A,
      `socket id=${String(socketMsgA.id)} (no REST poll)`,
    );
  } catch (error) {
    record(
      "realtime.B.receivesA",
      false,
      error instanceof Error ? error.message : String(error),
    );
  }

  const pendingA = waitForMessage(
    socketA,
    (msg) => msg.text === "reply from B realtime",
  );
  const sendB = await api(tokenB, "POST", `/api/outings/${outingId}/messages`, {
    text: "reply from B realtime",
  });
  const msgB = dataOf<{ id?: string; sender_id?: string }>(sendB.data);
  record(
    "rest.B.send",
    sendB.status === 201 && msgB?.sender_id === UID_B,
    `status=${sendB.status} id=${msgB?.id ?? "n/a"}`,
  );

  try {
    const socketMsgB = await pendingA;
    record(
      "realtime.A.receivesB",
      socketMsgB.id === msgB?.id && socketMsgB.sender_id === UID_B,
      `socket id=${String(socketMsgB.id)} (no REST poll)`,
    );
  } catch (error) {
    record(
      "realtime.A.receivesB",
      false,
      error instanceof Error ? error.message : String(error),
    );
  }

  // Duplicate delivery: A should also get own echo once; count by id after B's room
  const neonCount = await prisma.chat_messages.count({
    where: {
      outing_id: outingId,
      id: { in: [msgA?.id, msgB?.id].filter(Boolean) as string[] },
    },
  });
  record("neon.persistedBoth", neonCount === 2, `matched=${neonCount}`);

  // No duplicate rows for same clientMessageId
  const clientMessageId = crypto.randomUUID();
  const first = await api(tokenA, "POST", `/api/outings/${outingId}/messages`, {
    text: "idempotent",
    clientMessageId,
  });
  const second = await api(tokenA, "POST", `/api/outings/${outingId}/messages`, {
    text: "idempotent",
    clientMessageId,
  });
  const id1 = dataOf<{ id?: string }>(first.data)?.id;
  const id2 = dataOf<{ id?: string }>(second.data)?.id;
  const dupCount = await prisma.chat_messages.count({
    where: {
      outing_id: outingId,
      sender_id: UID_A,
      client_message_id: clientMessageId,
    },
  });
  record(
    "dedupe.clientMessageId",
    id1 === id2 && dupCount === 1,
    `id1=${id1} id2=${id2} rows=${dupCount}`,
  );

  // Reconnect + REST recovery
  socketB.disconnect();
  const missed = await api(tokenA, "POST", `/api/outings/${outingId}/messages`, {
    text: "missed while B offline",
  });
  const missedId = dataOf<{ id?: string }>(missed.data)?.id;
  socketB = await connectSocket(tokenB);
  const rejoin = await joinOuting(socketB, outingId);
  record("socket.B.reconnectJoin", rejoin.ok === true, JSON.stringify(rejoin));
  const history = await api(tokenB, "GET", `/api/outings/${outingId}/messages`);
  const list = dataOf<Array<{ id?: string }>>(history.data) ?? [];
  record(
    "rest.reconnectMissedRecovery",
    list.some((m) => m.id === missedId),
    `recovered missed=${missedId} count=${list.length}`,
  );

  // REST authZ regression
  const strangerList = await api(
    tokenStranger,
    "GET",
    `/api/outings/${outingId}/messages`,
  );
  record(
    "security.strangerListForbidden",
    strangerList.status === 403,
    `status=${strangerList.status}`,
  );

  const realtimePass = results
    .filter((r) => r.scenario.startsWith("realtime."))
    .every((r) => r.ok);
  record(
    "realtime.twoUserBidirectional",
    realtimePass,
    realtimePass
      ? "A↔B exchanged over Socket.IO without polling"
      : "one or more realtime steps failed",
  );
}

socketA?.close();
socketB?.close();
socketStranger?.close();

const failed = results.filter((r) => !r.ok);
console.log("\n--- summary ---");
console.log(
  JSON.stringify(
    {
      outingId,
      groupId,
      total: results.length,
      failed: failed.map((f) => f.scenario),
      realtimePass: results.find((r) => r.scenario === "realtime.twoUserBidirectional")
        ?.ok,
    },
    null,
    2,
  ),
);

await prisma.$disconnect();
process.exit(failed.length > 0 ? 1 : 0);
