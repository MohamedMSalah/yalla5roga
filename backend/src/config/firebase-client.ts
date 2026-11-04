import { randomUUID } from "node:crypto";
import { deleteApp, initializeApp, type FirebaseApp } from "firebase/app";
import {
  inMemoryPersistence,
  initializeAuth,
  signInWithCustomToken,
  type Auth,
} from "firebase/auth";

export type FirebaseClientConfig = {
  apiKey: string;
  authDomain: string;
  projectId: string;
};

function readClientConfig(): FirebaseClientConfig {
  const projectId = process.env.FIREBASE_PROJECT_ID;
  const apiKey = process.env.FIREBASE_API_KEY;

  if (!projectId || !apiKey) {
    throw new Error(
      "Missing Firebase client config. Set FIREBASE_PROJECT_ID and FIREBASE_API_KEY",
    );
  }

  return {
    apiKey,
    authDomain: `${projectId}.firebaseapp.com`,
    projectId,
  };
}

/**
 * Runs Firebase Auth client SDK work on an ephemeral app so concurrent
 * API requests do not share a singleton `currentUser`.
 */
async function withClientAuth<T>(
  run: (auth: Auth, app: FirebaseApp) => Promise<T>,
): Promise<T> {
  const config = readClientConfig();
  const app = initializeApp(config, `auth-${randomUUID()}`);

  try {
    const auth = initializeAuth(app, { persistence: inMemoryPersistence });
    return await run(auth, app);
  } finally {
    await deleteApp(app);
  }
}

export type EmailPasswordSession = {
  uid: string;
  email: string | null;
  idToken: string;
  refreshToken: string;
  expiresIn: string;
};

/** Exchange a Firebase Admin custom token for an ID token session. */
export async function signInWithCustomTokenSession(
  customToken: string,
): Promise<EmailPasswordSession> {
  return withClientAuth(async (auth) => {
    const credential = await signInWithCustomToken(auth, customToken);
    const idToken = await credential.user.getIdToken();
    return {
      uid: credential.user.uid,
      email: credential.user.email,
      idToken,
      refreshToken: credential.user.refreshToken,
      expiresIn: "3600",
    };
  });
}
