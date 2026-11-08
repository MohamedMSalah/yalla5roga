/**
 * Simulates Flutter ApiClient call shapes against the live backend.
 * Verifies HTTP status + Neon persistence for major scenarios.
 */
import "dotenv/config";
import fs from "node:fs";
import { prisma } from "../src/config/database.js";
import { getFirebaseAuth } from "../src/config/firebase.js";

const UID = "flutter-scenario-probe";
const flutterEnv = fs.readFileSync("../flutter/.env", "utf8");
const apiKey = flutterEnv
  .split(/\r?\n/)
  .find((line) => line.startsWith("FIREBASE_ANDROID_API_KEY="))
  ?.split("=")[1]
  ?.trim();
if (!apiKey) throw new Error("missing android api key");

const auth = getFirebaseAuth();
const customToken = await auth.createCustomToken(UID);
const exchange = await fetch(
  `https://identitytoolkit.googleapis.com/v1/accounts:signInWithCustomToken?key=${apiKey}`,
  {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ token: customToken, returnSecureToken: true }),
  },
);
const exchanged = (await exchange.json()) as { idToken?: string };
if (!exchanged.idToken) {
  console.log(JSON.stringify({ phase: "firebase_exchange", ...exchanged }));
  process.exit(1);
}

const headers = {
  Authorization: `Bearer ${exchanged.idToken}`,
  "Content-Type": "application/json",
};
const base = "http://127.0.0.1:3000";

type Hit = {
  scenario: string;
  method: string;
  path: string;
  status: number;
  ok: boolean;
  detail?: string;
  neon?: Record<string, number | string | boolean | null>;
};

const results: Hit[] = [];

async function hit(
  scenario: string,
  method: string,
  path: string,
  body?: Record<string, unknown>,
  expectOk: (status: number, data: unknown) => boolean = (s) =>
    s >= 200 && s < 300,
) {
  const response = await fetch(base + path, {
    method,
    headers,
    body: body ? JSON.stringify(body) : undefined,
  });
  const text = await response.text();
  let data: unknown = text;
  try {
    data = JSON.parse(text);
  } catch {
    // keep text
  }
  const ok = expectOk(response.status, data);
  const message =
    typeof data === "object" && data && "message" in data
      ? String((data as { message?: string }).message ?? "")
      : "";
  results.push({
    scenario,
    method,
    path,
    status: response.status,
    ok,
    detail: message || undefined,
  });
  return { status: response.status, data, ok };
}

// --- Auth / sync (Flutter: AuthRemoteDataSource) ---
await hit("auth.sync", "POST", "/api/users/sync", {});
await hit("auth.profile", "GET", "/api/users/cuser");

// --- Groups (Flutter: GroupsRemoteDataSource) ---
const groupCreate = await hit("groups.create", "POST", "/api/groups", {
  name: "Probe Group",
  bio: "integration",
});
const groupId = (
  groupCreate.data as { data?: { id?: string } } | undefined
)?.data?.id;
await hit("groups.cuser", "GET", "/api/groups/cuser");
if (groupId) {
  await hit("groups.get", "GET", `/api/groups/${groupId}`);
  await hit("groups.members", "GET", `/api/groups/${groupId}/members`);
  await hit("groups.patch", "PATCH", `/api/groups/${groupId}`, {
    name: "Probe Group 2",
    bio: "updated",
  });
}

// --- Outings create + vote options + attendance (Flutter outings DS) ---
const deadline = new Date(Date.now() + 3 * 60 * 60 * 1000).toISOString();
const outingBody = groupId
  ? {
      title: "Probe Outing",
      group_id: groupId,
      status: "draft",
      occasion: "none",
      vote_deadline_hours: 3,
      vote_ends_at: deadline,
    }
  : {
      title: "Probe Outing",
      type: "special",
      occasion: "birthday",
      vote_deadline_hours: 3,
      vote_ends_at: deadline,
    };

const created = await hit("outings.create", "POST", "/api/outings", outingBody);
const outingId = (created.data as { data?: { id?: string } })?.data?.id;

let optionId: string | undefined;
if (outingId) {
  await hit("outings.cuser", "GET", "/api/outings/cuser");
  const opt = await hit(
    "voting.addOption",
    "POST",
    `/api/outings/${outingId}/vote-options`,
    {
      label: "Cafe Probe",
      vibe: "food",
      sort_order: 0,
    },
  );
  optionId = (opt.data as { data?: { id?: string } })?.data?.id;

  await hit(
    "voting.listOptions",
    "GET",
    `/api/outings/${outingId}/vote-options`,
  );
  if (optionId) {
    await hit("voting.cast", "POST", `/api/outings/${outingId}/votes`, {
      option_id: optionId,
    });
  }
  await hit("voting.listVotes", "GET", `/api/outings/${outingId}/votes`);
  await hit(
    "voting.state",
    "GET",
    `/api/outings/${outingId}/voting-state`,
  );

  await hit(
    "participants.attendanceGet",
    "GET",
    `/api/outings/${outingId}/attendance`,
  );
  await hit(
    "participants.attendancePut",
    "PUT",
    `/api/outings/${outingId}/attendance`,
    { status: "going" },
  );

  // Chat (Flutter OutingChatRemoteDataSource)
  await hit("chat.send", "POST", `/api/outings/${outingId}/messages`, {
    text: "scenario probe message",
  });
  const list = await hit(
    "chat.list",
    "GET",
    `/api/outings/${outingId}/messages`,
  );
  const messages = (list.data as { data?: unknown[] })?.data;
  const first = Array.isArray(messages) ? messages[0] : null;
  const hasSenderId =
    !!first &&
    typeof first === "object" &&
    ("sender_id" in first || "senderId" in first);
  results.push({
    scenario: "chat.list.hasSenderId",
    method: "ASSERT",
    path: `/api/outings/${outingId}/messages`,
    status: list.status,
    ok: hasSenderId,
    detail: hasSenderId
      ? "sender_id present for Flutter isMine enrichment"
      : "missing sender_id — Flutter provider cannot mark isMine",
  });
  await hit("chat.read", "PATCH", `/api/outings/${outingId}/read`);

  // Saved outings
  await hit("saved.save", "POST", `/api/outings/${outingId}/save`);
  await hit("saved.list", "GET", "/api/outings/saved");

  // Neon checks
  const neonMsg = await prisma.chat_messages.count({
    where: { outing_id: outingId },
  });
  const neonSave = await prisma.saved_outings.count({
    where: { outing_id: outingId, user_id: UID },
  });
  const neonVote = optionId
    ? await prisma.outing_votes.count({
        where: { outing_id: outingId, user_id: UID, option_id: optionId },
      })
    : 0;
  const neonAttend = await prisma.outing_attendance.count({
    where: { outing_id: outingId, user_id: UID, status: "going" },
  });
  results.push({
    scenario: "neon.persistence",
    method: "ASSERT",
    path: "prisma",
    status: 200,
    ok: neonMsg >= 1 && neonSave >= 1 && neonVote >= 1 && neonAttend >= 1,
    neon: { neonMsg, neonSave, neonVote, neonAttend, outingId, groupId: groupId ?? null },
  });
}

// Notifications
await hit("notifications.list", "GET", "/api/notifications");
await hit("notifications.readAll", "PATCH", "/api/notifications/read");

// FCM (Flutter FcmTokenRemoteDataSource)
const fcmTok = `scenario-fcm-${Date.now()}-abcdefghij`;
await hit("fcm.register", "POST", "/api/users/cuser/fcm-token", {
  token: fcmTok,
  platform: "android",
});
const fcmCount = await prisma.user_fcm_tokens.count({
  where: { user_id: UID, token: fcmTok },
});
results.push({
  scenario: "neon.fcm",
  method: "ASSERT",
  path: "/api/users/cuser/fcm-token",
  status: 200,
  ok: fcmCount === 1,
  neon: { fcmCount },
});
await hit(
  "fcm.unregister",
  "DELETE",
  `/api/users/cuser/fcm-token/${encodeURIComponent(fcmTok)}`,
);

// Discover
await hit("discover.places", "GET", "/api/places");

// Regression: old paths must 404
await hit(
  "regression.oldChat",
  "GET",
  `/api/chat/outings/${outingId ?? "00000000-0000-4000-8000-000000000001"}/messages`,
  undefined,
  (s) => s === 404,
);
await hit(
  "regression.oldFcm",
  "POST",
  "/api/user/fcm-token",
  { token: "x" },
  (s) => s === 404,
);

const failed = results.filter((r) => !r.ok);
console.log(
  JSON.stringify(
    {
      firebaseAuth: "customToken→idToken OK",
      total: results.length,
      passed: results.length - failed.length,
      failed: failed.length,
      results,
    },
    null,
    2,
  ),
);

await prisma.$disconnect();
process.exit(failed.length ? 1 : 0);
