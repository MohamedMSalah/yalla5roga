import "./support/isolated-database.js";
import assert from "node:assert/strict";
import { test } from "node:test";
import { getAuth, type DecodedIdToken } from "firebase-admin/auth";
import { deleteApp, initializeApp } from "firebase-admin/app";
import { withApi } from "./support/http-fixture.js";

process.env.NODE_ENV = "production";
process.env.CORS_ORIGINS = "https://staging.example.invalid";
delete process.env.R2_BUCKET_NAME;
const { default: app, routeInventory } = await import("../src/app.js");
const { attachRealtime } = await import("../src/realtime/socket-server.js");
const { verifyAppSession } = await import("../src/middleware/auth.middleware.js");
const { MediaService } = await import("../src/services/media/media.service.js");

test("production excludes the docs and mock media and applies the socket origin policy", async () => {
  assert.ok(!routeInventory.some(route => route.path.includes("/mock-")));
  assert.throws(() => new MediaService().storage(), { statusCode: 503 });
  await withApi(app, async (base, server) => {
    const realtime = attachRealtime(server);
    try {
      assert.equal((await fetch(base + "/api-docs/openapi.json")).status, 404);
      const handshake = base + "/socket.io/?EIO=4&transport=polling";
      assert.equal((await fetch(handshake, {
        headers: { Origin: "https://untrusted.example.invalid" },
      })).status, 403);
      assert.equal((await fetch(handshake, {
        headers: { Origin: "https://staging.example.invalid" },
      })).status, 200);
    } finally {
      await realtime.close();
    }
  });
});

test("production session verification requests Firebase revocation checks", async () => {
  const fixture = initializeApp({ projectId: "demo-production-boundaries" });
  const auth = getAuth(fixture);
  try {
    auth.verifyIdToken = async (token, checkRevoked) => {
      assert.equal(checkRevoked, true);
      if (token === "revoked") {
        throw Object.assign(new Error("Fixture revoked token"), { code: "auth/id-token-revoked" });
      }
      return { uid: "fixture-user", firebase: { sign_in_provider: "custom" } } as DecodedIdToken;
    };
    assert.equal((await verifyAppSession("valid")).uid, "fixture-user");
    await assert.rejects(verifyAppSession("revoked"), { code: "auth/id-token-revoked" });
  } finally {
    await deleteApp(fixture);
  }
});
