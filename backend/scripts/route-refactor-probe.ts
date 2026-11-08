import "dotenv/config";
import fs from "node:fs";
import { getFirebaseAuth } from "../src/config/firebase.js";

const flutterEnv = fs.readFileSync("../flutter/.env", "utf8");
const apiKey = flutterEnv
  .split(/\r?\n/)
  .find((line) => line.startsWith("FIREBASE_ANDROID_API_KEY="))
  ?.split("=")[1]
  ?.trim();
if (!apiKey) throw new Error("missing android api key");

const auth = getFirebaseAuth();
const customToken = await auth.createCustomToken("route-refactor-probe");
const exchange = await fetch(
  `https://identitytoolkit.googleapis.com/v1/accounts:signInWithCustomToken?key=${apiKey}`,
  {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ token: customToken, returnSecureToken: true }),
  },
);
const exchanged = (await exchange.json()) as {
  idToken?: string;
  error?: { message?: string };
};
if (!exchanged.idToken) {
  console.log(JSON.stringify({ exchangeFailed: true, ...exchanged }));
  process.exit(1);
}

const token = exchanged.idToken;
const base = "http://127.0.0.1:3000";

async function hit(
  method: string,
  path: string,
  body?: Record<string, unknown>,
) {
  const response = await fetch(base + path, {
    method,
    headers: {
      Authorization: `Bearer ${token}`,
      ...(body ? { "Content-Type": "application/json" } : {}),
    },
    body: body ? JSON.stringify(body) : undefined,
  });
  const text = await response.text();
  let message: unknown = text.slice(0, 160);
  try {
    const parsed = JSON.parse(text) as { message?: string; success?: boolean };
    message = parsed.message ?? parsed.success;
  } catch {
    // keep raw slice
  }
  return { method, path, status: response.status, message };
}

const results = [
  await hit("POST", "/api/users/sync", {}),
  await hit("GET", "/api/users/cuser"),
  await hit("GET", "/api/groups/cuser"),
  await hit("GET", "/api/outings/cuser"),
  await hit("GET", "/api/outings/saved"),
  await hit("GET", "/api/notifications"),
  await hit("POST", "/api/users/cuser/fcm-token", {
    token: "probe-fcm-token-1234567890",
    platform: "android",
  }),
  await hit(
    "DELETE",
    `/api/users/cuser/fcm-token/${encodeURIComponent("probe-fcm-token-1234567890")}`,
  ),
  await hit(
    "GET",
    "/api/outings/00000000-0000-4000-8000-000000000001/messages",
  ),
  await hit(
    "GET",
    "/api/chat/outings/00000000-0000-4000-8000-000000000001/messages",
  ),
  await hit("POST", "/api/user/fcm-token", { token: "x" }),
  await hit("GET", "/api/places"),
];

console.log(JSON.stringify(results, null, 2));
