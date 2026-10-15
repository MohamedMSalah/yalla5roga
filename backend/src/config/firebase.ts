import { cert, getApps, initializeApp } from "firebase-admin/app";
import { getAuth } from "firebase-admin/auth";

export function initFirebase() {
  const existing = getApps();
  if (existing.length > 0) {
    console.error("[Firebase Admin] Reusing existing app", {
      appCount: existing.length,
      projectIds: existing.map((app) => app.options.projectId ?? null),
    });
    return;
  }

  const projectId = process.env.FIREBASE_PROJECT_ID;
  const clientEmail = process.env.FIREBASE_CLIENT_EMAIL;
  // Env files often store the PEM as one line with literal "\n" sequences.
  const privateKey = process.env.FIREBASE_PRIVATE_KEY?.replace(/\\n/g, "\n");

  if (!projectId || !clientEmail || !privateKey) {
    throw new Error(
      "Missing Firebase config. Set FIREBASE_PROJECT_ID, FIREBASE_CLIENT_EMAIL, and FIREBASE_PRIVATE_KEY",
    );
  }

  initializeApp({
    projectId,
    credential: cert({
      projectId,
      clientEmail,
      privateKey,
    }),
  });
}

export function getFirebaseAuth() {
  initFirebase();
  return getAuth();
}
