import assert from "node:assert/strict";
import { mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, sep } from "node:path";
import { pathToFileURL } from "node:url";
import test from "node:test";
import { loadEnvironment } from "../../scripts/environment.mjs";
import { clientArguments } from "../../scripts/flutter-config.mjs";

test("device uses only its file and production accepts injected settings and multiline values", () => {
  const dir = mkdtempSync(join(tmpdir(), "yalla-env-fixture-"));
  const directory = pathToFileURL(dir + sep);
  try {
    writeFileSync(join(dir, ".env.device"), "DATABASE_URL=postgres://loopback/yalla_test\nHOST=127.0.0.1\n");
    writeFileSync(join(dir, ".env.production"), 'DATABASE_URL=postgres://prod.invalid/main\nFIREBASE_PRIVATE_KEY="first\nlast"\n');
    const target = { DATABASE_URL: "postgres://prod.invalid/main", FIREBASE_PRIVATE_KEY: "injected", HOST: "injected" };
    const device = loadEnvironment("device", { target, directory });
    assert.equal(device.DATABASE_URL, "postgres://loopback/yalla_test");
    assert.equal(device.HOST, "127.0.0.1");
    assert.equal(device.FIREBASE_PRIVATE_KEY, undefined);
    const production = loadEnvironment("production", { target: { DATABASE_URL: "injected" }, directory });
    assert.equal(production.DATABASE_URL, "injected");
    assert.equal(production.FIREBASE_PRIVATE_KEY, "first\nlast");
    assert.equal(production.NODE_ENV, "production");
    writeFileSync(join(dir, ".env.device"), "DATABASE_URL=postgres://prod-pooler.invalid/main\n");
    assert.throws(() => loadEnvironment("device", { target: {}, directory }), /production database/);
  } finally {
    rmSync(dir, { recursive: true });
  }
});

test("client arguments exclude secrets and require an HTTPS release origin", () => {
  const values = {
    APP_ENV: "production", API_BASE_URL: "https://api.example.org",
    FIREBASE_PROJECT_ID: "fixture", FIREBASE_ANDROID_API_KEY: "public-key", FIREBASE_ANDROID_APP_ID: "android",
    FIREBASE_IOS_API_KEY: "ios", FIREBASE_IOS_APP_ID: "ios", FIREBASE_MESSAGING_SENDER_ID: "1",
    FIREBASE_STORAGE_BUCKET: "fixture", FIREBASE_IOS_BUNDLE_ID: "com.example.test",
    FIREBASE_IOS_CLIENT_ID: "client", FIREBASE_WEB_CLIENT_ID: "web",
    FIREBASE_PRIVATE_KEY: "secret", FIREBASE_API_KEY: "server", DATABASE_URL: "postgres://secret",
    R2_SECRET_ACCESS_KEY: "secret", WHATSAPP_ACCESS_TOKEN: "secret", MONITORING_TOKEN: "secret",
    STORE_PASSWORD: "secret",
  };
  const args = clientArguments("production", values);
  assert.equal(args.length, 12);
  assert.ok(args.includes("--dart-define=FIREBASE_ANDROID_API_KEY=public-key"));
  assert.ok(args.every(arg => !/secret|--dart-define-from-file|STORE_PASSWORD/.test(arg)));
  assert.throws(() => clientArguments("production", { ...values, API_BASE_URL: "http://api.example.org" }), /HTTPS/);
  assert.throws(() => clientArguments("device", values), /APP_ENV/);
});
