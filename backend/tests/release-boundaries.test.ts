import assert from "node:assert/strict";
import { once } from "node:events";
import { test } from "node:test";
import express from "express";
import { deleteApp, initializeApp } from "firebase-admin/app";
import { getAuth } from "firebase-admin/auth";
import { io as connect } from "socket.io-client";
import { trustedProxyAddresses, validateProductionConfig } from "../src/config/deployment.js";
import { apiRateLimit } from "../src/middleware/api-rate-limit.middleware.js";
import { attachRealtime } from "../src/realtime/socket-server.js";
import { bindChatEmitter } from "../src/realtime/chat-emitter.js";
import { userRealtimeRoom } from "../src/realtime/rooms.js";
import { withApi } from "./support/http-fixture.js";
import { getApps } from "@firebase/app";

test("the narrowed Firebase client exchanges independent custom sessions and releases its apps", async t => {
  t.mock.method(globalThis, "fetch", async (input: string | URL | Request, init?: RequestInit) => {
    const url = new URL(String(input));
    assert.equal(url.hostname, "identitytoolkit.googleapis.com");
    assert.equal(url.searchParams.get("key"), "offline-key");
    const body = JSON.parse(String(init?.body));
    if (url.pathname.endsWith("accounts:signInWithCustomToken")) {
      const uid = body.token;
      return Response.json({ localId: uid, idToken: `token-${uid}`, refreshToken: `refresh-${uid}`, expiresIn: "3600" });
    }
    assert.ok(url.pathname.endsWith("accounts:lookup"));
    return Response.json({ users: [{ localId: body.idToken.replace(/^token-/, "") }] });
  });
  const original = {
    FIREBASE_PROJECT_ID: process.env.FIREBASE_PROJECT_ID,
    FIREBASE_API_KEY: process.env.FIREBASE_API_KEY,
  };
  process.env.FIREBASE_PROJECT_ID = "demo-yalla-session-fixtures";
  process.env.FIREBASE_API_KEY = "offline-key";
  try {
    const { signInWithCustomTokenSession } = await import("../src/config/firebase-client.js");
    const sessions = await Promise.all(["one", "two"].map(signInWithCustomTokenSession));
    assert.deepEqual(sessions.map(session => session.uid), ["one", "two"]);
    assert.deepEqual(sessions.map(session => session.refreshToken), ["refresh-one", "refresh-two"]);
    assert.ok(getApps().every(app => !app.name.startsWith("auth-")));
  } finally {
    for (const [key, value] of Object.entries(original)) {
      if (value === undefined) delete process.env[key];
      else process.env[key] = value;
    }
  }
});

test("production configuration refuses mixed provider targets and unsafe proxy settings", () => {
  const staging = {
    DEPLOYMENT_ENV: "staging",
    FIREBASE_PROJECT_ID: "isolated-staging",
    EXPECTED_FIREBASE_PROJECT_ID: "isolated-staging",
    FIREBASE_CLIENT_EMAIL: "tester@isolated-staging.iam.gserviceaccount.com",
    FIREBASE_API_KEY: "fixture",
    FIREBASE_PRIVATE_KEY: "fixture",
    CORS_ORIGINS: "https://app.staging.example",
    TRUST_PROXY: "192.0.2.0/24,2001:db8::5",
    DATABASE_URL: "postgres://fixture@db.staging.example/app?sslmode=require",
    DIRECT_URL: "postgres://migrator@db.staging.example/app?sslmode=verify-full",
    EXPECTED_DATABASE_HOST: "db.staging.example",
    EXPECTED_DATABASE_NAME: "app",
    R2_ACCOUNT_ID: "fixture",
    EXPECTED_R2_ACCOUNT_ID: "fixture",
    R2_ACCESS_KEY_ID: "fixture",
    R2_SECRET_ACCESS_KEY: "fixture",
    R2_BUCKET_NAME: "private-staging",
    EXPECTED_R2_PRIVATE_BUCKET: "private-staging",
    R2_PUBLIC_BUCKET_NAME: "public-staging",
    EXPECTED_R2_PUBLIC_BUCKET: "public-staging",
    R2_PUBLIC_BASE_URL: "https://assets.staging.example",
  };
  assert.doesNotThrow(() => validateProductionConfig(staging));
  for (const [override, reason] of [
    [{ FIREBASE_PROJECT_ID: "different" }, /FIREBASE_PROJECT_ID/],
    [{ FIREBASE_AUTH_EMULATOR_HOST: "127.0.0.1:9099" }, /FIREBASE_PROJECT_ID/],
    [{ DIRECT_URL: "postgres://migrator@db.production.example/app?sslmode=require" }, /DIRECT_URL/],
    [{ DATABASE_URL: "postgres://fixture@db.staging.example/app?sslmode=disable" }, /DATABASE_URL/],
    [{ TRUST_PROXY: "0.0.0.0/0" }, /TRUST_PROXY/],
    [{ CORS_ORIGINS: "http://app.staging.example" }, /CORS_ORIGINS/],
    [{ R2_PUBLIC_BUCKET_NAME: "private-staging" }, /separate/],
    [{ R2_ENDPOINT: "https://different.r2.cloudflarestorage.com" }, /R2_ENDPOINT/],
  ] as const) {
    assert.throws(() => validateProductionConfig({ ...staging, ...override }), reason);
  }
});

test("client rate buckets use the nearest untrusted hop and ignore untrusted forwarding", {
  timeout: 20_000,
}, async () => {
  for (const trusted of [false, true]) {
    const app = express();
    app.set("trust proxy", trustedProxyAddresses(trusted ? "127.0.0.1/32" : "192.0.2.5"));
    app.get("/", apiRateLimit, (_req, res) => res.sendStatus(200));
    await withApi(app, async base => {
      const request = async (header: string) => {
        const response = await fetch(base, { headers: { "X-Forwarded-For": header } });
        await response.arrayBuffer();
        return response;
      };
      for (let i = 0; i < 300; i++) {
        assert.equal((await request(`203.0.113.${i % 200 + 1}, 198.51.100.1`)).status, 200);
      }
      const limited = await request("203.0.113.201, 198.51.100.1");
      assert.equal(limited.status, 429);
      assert.match(limited.headers.get("retry-after") ?? "", /^\d+$/);
      assert.equal((await request("198.51.100.2")).status, trusted ? 200 : 429);
    });
  }
});

test("established sockets recheck revocation, disabled identity and expiry, then clean rooms", {
  timeout: 15_000,
}, async t => {
  const firebase = initializeApp({ projectId: "demo-yalla-socket-sessions" });
  const rejected = new Map<string, string>();
  const uid = "disposable-socket-uid";
  const auth = getAuth(firebase);
  const verifies = t.mock.method(auth, "verifyIdToken", async (token: string, checkRevoked: boolean) => {
    assert.equal(checkRevoked, true);
    const code = rejected.get(token);
    if (code) throw Object.assign(new Error("Session rejected"), { code });
    return {
      uid, exp: token === "expiring" ? Math.floor(Date.now() / 1000) + 2 : Math.floor(Date.now() / 1000) + 60,
      firebase: { sign_in_provider: "custom" },
    };
  });
  try {
    await withApi(express(), async (base, server) => {
      const realtime = attachRealtime(server, 250);
      const clients: ReturnType<typeof connect>[] = [];
      const clientFor = (token: string) => {
        const client = connect(base, {
          transports: ["websocket"], reconnection: false, auth: { token },
        });
        clients.push(client);
        return client;
      };
      try {
        for (const code of ["auth/id-token-revoked", "auth/user-disabled", "auth/user-not-found", "auth/network-request-failed"]) {
          const client = clientFor(code);
          await once(client, "connect");
          assert.ok(realtime.of("/").adapter.rooms.has(userRealtimeRoom(uid)));
          const before = verifies.mock.callCount();
          await Promise.all(Array.from({ length: 3 }, () => client.timeout(2000).emitWithAck("data:reconcile", null)));
          assert.equal(verifies.mock.callCount(), before);
          rejected.set(code, code);
          await once(client, "disconnect");
          assert.equal(realtime.of("/").adapter.rooms.has(userRealtimeRoom(uid)), false);
          const retry = clientFor(code);
          const [error] = await once(retry, "connect_error");
          assert.equal(error.message, "UNAUTHORIZED");
        }
        const expires = clientFor("expiring");
        await once(expires, "connect");
        await once(expires, "disconnect");
        assert.equal(realtime.of("/").adapter.rooms.has(userRealtimeRoom(uid)), false);
        const refreshed = clientFor("fresh");
        await once(refreshed, "connect");
        assert.ok(realtime.of("/").adapter.rooms.has(userRealtimeRoom(uid)));
      } finally {
        for (const client of clients) client.disconnect();
        await realtime.close();
        bindChatEmitter(null);
      }
    });
  } finally {
    await deleteApp(firebase);
  }
});
