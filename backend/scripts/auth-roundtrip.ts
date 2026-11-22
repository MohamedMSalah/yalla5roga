import { getApp } from "firebase-admin/app";
import { getFirebaseAuth } from "../src/config/firebase.js";

const apiKey = process.env.FIREBASE_ANDROID_API_KEY?.trim();
if (!apiKey) throw new Error("Set FIREBASE_ANDROID_API_KEY in the selected profile");

const auth = getFirebaseAuth();
const uid = "swagger-auth-check";
const customToken = await auth.createCustomToken(uid);
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
  console.log(
    JSON.stringify({
      exchangeFailed: true,
      status: exchange.status,
      message: exchanged.error?.message ?? "no id token",
    }),
  );
  process.exit(1);
}

const idToken = exchanged.idToken;
const base = "http://127.0.0.1:3000";

async function hit(path: string, headers: Record<string, string> = {}) {
  const response = await fetch(base + path, { headers });
  const text = await response.text();
  let body: { message?: string; success?: boolean; data?: unknown };
  try {
    body = JSON.parse(text) as typeof body;
  } catch {
    body = { message: text.slice(0, 80) };
  }
  return {
    path,
    status: response.status,
    message: body.message ?? null,
    success: body.success ?? null,
  };
}

const results = {
  projectId: getApp().options.projectId ?? null,
  tokenSegments: idToken.split(".").length,
  doubleBearer: await hit("/api/groups/cuser", {
    Authorization: `Bearer Bearer ${idToken}`,
  }),
  quoted: await hit("/api/groups/cuser", {
    Authorization: `Bearer "${idToken}"`,
  }),
  validGroups: await hit("/api/groups/cuser", {
    Authorization: `Bearer ${idToken}`,
  }),
  validUsers: await hit("/api/users/cuser", {
    Authorization: `Bearer ${idToken}`,
  }),
  missing: await hit("/api/groups/cuser"),
  malformed: await hit("/api/groups/cuser", { Authorization: "Token abc" }),
  invalid: await hit("/api/groups/cuser", {
    Authorization: "Bearer not-a-jwt",
  }),
  publicRoot: await hit("/"),
  publicPlaces: await hit("/api/places"),
};

console.log(JSON.stringify(results, null, 2));
