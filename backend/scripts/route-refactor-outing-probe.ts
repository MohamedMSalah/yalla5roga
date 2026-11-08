import "dotenv/config";
import fs from "node:fs";
import { prisma } from "../src/config/database.js";
import { getFirebaseAuth } from "../src/config/firebase.js";

const UID = "route-refactor-probe";
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
  console.log(JSON.stringify(exchanged));
  process.exit(1);
}

const headers = {
  Authorization: `Bearer ${exchanged.idToken}`,
  "Content-Type": "application/json",
};
const base = "http://127.0.0.1:3000";

async function j(method: string, path: string, body?: Record<string, unknown>) {
  const response = await fetch(base + path, {
    method,
    headers,
    body: body ? JSON.stringify(body) : undefined,
  });
  const text = await response.text();
  let parsed: { success?: boolean; data?: unknown; message?: string } = {};
  try {
    parsed = JSON.parse(text) as typeof parsed;
  } catch {
    parsed = { message: text.slice(0, 200) };
  }
  return { status: response.status, body: parsed };
}

await j("POST", "/api/users/sync", {});
const deadline = new Date(Date.now() + 2 * 60 * 60 * 1000).toISOString();
const created = await j("POST", "/api/outings", {
  title: "Route refactor probe",
  type: "special",
  occasion: "birthday",
  vote_ends_at: deadline,
  vote_deadline_hours: 2,
});
const outingId = (created.body.data as { id?: string } | undefined)?.id;

const msg = outingId
  ? await j("POST", `/api/outings/${outingId}/messages`, {
      text: "hello from probe",
    })
  : { status: 0, body: { message: "no outing" } };
const list = outingId
  ? await j("GET", `/api/outings/${outingId}/messages`)
  : { status: 0, body: { message: "no outing" } };
const read = outingId
  ? await j("PATCH", `/api/outings/${outingId}/read`)
  : { status: 0, body: { message: "no outing" } };
const save = outingId
  ? await j("POST", `/api/outings/${outingId}/save`)
  : { status: 0, body: { message: "no outing" } };
const saved = await j("GET", "/api/outings/saved");
const votes = outingId
  ? await j("GET", `/api/outings/${outingId}/voting-state`)
  : { status: 0, body: { message: "no outing" } };
const attendance = outingId
  ? await j("GET", `/api/outings/${outingId}/attendance`)
  : { status: 0, body: { message: "no outing" } };

const neonMsg = outingId
  ? await prisma.chat_messages.count({ where: { outing_id: outingId } })
  : -1;
const neonSave = outingId
  ? await prisma.saved_outings.count({
      where: { outing_id: outingId, user_id: UID },
    })
  : -1;

console.log(
  JSON.stringify(
    {
      createdStatus: created.status,
      createdMessage: created.body.message ?? null,
      outingId: outingId ?? null,
      msgStatus: msg.status,
      listStatus: list.status,
      listCount: Array.isArray(list.body.data) ? list.body.data.length : null,
      readStatus: read.status,
      saveStatus: save.status,
      savedStatus: saved.status,
      savedCount: Array.isArray(saved.body.data) ? saved.body.data.length : null,
      votesStatus: votes.status,
      attendanceStatus: attendance.status,
      neonMsg,
      neonSave,
    },
    null,
    2,
  ),
);

await prisma.$disconnect();
