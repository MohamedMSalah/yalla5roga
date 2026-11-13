import assert from "node:assert/strict";
import test from "node:test";
import { getMediaConfig, type MediaConfig } from "../src/config/media.js";
import type { IMediaRepository } from "../src/repositories/media/i-media.repository.js";
import {
  buildMediaReference,
  isMediaReference,
  MediaService,
  parseMediaReference,
} from "../src/services/media/media.service.js";
import { MockStorageAdapter } from "../src/services/media/mock-storage.adapter.js";
import type { MediaAsset } from "../src/types/media/media.types.js";
import { optionalMediaImageUrlSchema } from "../src/validators/media/image-url.validator.js";

// Place catalog media is curator-gated. This process is isolated per test file,
// so user-1 is the catalog curator and user-2 is an ordinary member.
process.env.PLACES_CURATOR_UIDS = "user-1";

function memoryRepository(): IMediaRepository & { rows: Map<string, MediaAsset> } {
  const rows = new Map<string, MediaAsset>();
  let counter = 0;
  const clone = (row: MediaAsset) => ({ ...row });
  return {
    rows,
    async create(data) {
      counter += 1;
      const row: MediaAsset = {
        id: `00000000-0000-4000-8000-${String(counter).padStart(12, "0")}`,
        ...data,
        status: "pending",
        user_id: null,
        group_id: null,
        outing_id: null,
        place_id: null,
        created_at: new Date(),
        updated_at: new Date(),
        verified_at: null,
      };
      rows.set(row.id, row);
      return clone(row);
    },
    async findById(id) {
      const row = rows.get(id);
      return row ? clone(row) : null;
    },
    async findByObjectKey(key) {
      for (const row of rows.values()) if (row.object_key === key) return clone(row);
      return null;
    },
    async refreshUploadExpiry(id, expiresAt) {
      const row = rows.get(id)!;
      row.upload_expires_at = expiresAt;
      row.status = "pending";
      return clone(row);
    },
    async markVerified(id, size, verifiedAt) {
      const row = rows.get(id)!;
      row.status = "ready";
      row.file_size = size;
      row.verified_at = verifiedAt;
      row.upload_expires_at = null;
      return clone(row);
    },
    async markFailed(id) {
      const row = rows.get(id)!;
      row.status = "failed";
      return clone(row);
    },
    async linkToEntity(id, link) {
      const row = rows.get(id)!;
      row.user_id = link.user_id ?? null;
      row.group_id = link.group_id ?? null;
      row.outing_id = link.outing_id ?? null;
      row.place_id = link.place_id ?? null;
      return clone(row);
    },
    async delete(id) {
      const row = rows.get(id)!;
      rows.delete(id);
      return clone(row);
    },
    async findExpiredPending(limit) {
      return [...rows.values()].filter((r) => r.status === "pending").slice(0, limit).map(clone);
    },
    async findFailed(limit) {
      return [...rows.values()].filter((r) => r.status === "failed").slice(0, limit).map(clone);
    },
  };
}

function makeService(overrides: Partial<MediaConfig> = {}) {
  const repo = memoryRepository();
  const adapter = new MockStorageAdapter("http://localhost:3000");
  const config: MediaConfig = {
    ...getMediaConfig(),
    provider: "mock" as const,
    publicBaseUrl: "https://media.example.com",
    publicBaseUrlConfigured: false,
    maxUploadBytes: 1024,
    allowedMimeTypes: ["image/jpeg", "image/png"],
    ...overrides,
  };
  const service = new MediaService(repo, config, adapter);
  return { repo, adapter, service };
}

test("media references use the stable media:// scheme", () => {
  const id = "0f8fad5b-d9cb-469f-a165-70867728950e";
  assert.equal(buildMediaReference(id), `media://${id}`);
  assert.equal(parseMediaReference(`media://${id}`), id);
  assert.equal(parseMediaReference("https://cdn.example.com/a.jpg"), null);
  assert.equal(isMediaReference(`media://${id}`), true);
  assert.equal(isMediaReference("media://not-a-uuid"), false);
});

test("image validators accept http(s) URLs and media references only", () => {
  assert.equal(optionalMediaImageUrlSchema.safeParse("").success, true);
  assert.equal(optionalMediaImageUrlSchema.safeParse(undefined).success, true);
  assert.equal(optionalMediaImageUrlSchema.safeParse("https://cdn.example.com/a.jpg").success, true);
  assert.equal(
    optionalMediaImageUrlSchema.safeParse("media://0f8fad5b-d9cb-469f-a165-70867728950e").success,
    true,
  );
  assert.equal(optionalMediaImageUrlSchema.safeParse("/local/picked/image.jpg").success, false);
  assert.equal(optionalMediaImageUrlSchema.safeParse("file:///tmp/a.jpg").success, false);
});

test("direct upload: request → store object → confirm marks ready", async () => {
  const { repo, adapter, service } = makeService();

  const intent = await service.requestUpload({
    uid: "user-1",
    purpose: "profile",
    mimeType: "image/jpeg",
    fileSize: 512,
  });

  assert.equal(intent.asset.status, "pending");
  assert.equal(intent.asset.visibility, "private");
  assert.match(intent.asset.object_key, /^profiles\/\d{4}-\d{2}\/.+\.jpg$/);
  assert.match(intent.upload_url, /\/api\/media\/mock-upload\//);

  adapter.store(intent.asset.object_key, new Uint8Array(512), "image/jpeg");
  const confirmed = await service.confirmUpload({ uid: "user-1", mediaId: intent.asset.id });

  assert.equal(confirmed.status, "ready");
  assert.equal(confirmed.file_size, 512);
  assert.ok(confirmed.verified_at);
  assert.equal(repo.rows.get(confirmed.id)?.status, "ready");
});

test("confirm without an uploaded object marks the asset failed", async () => {
  const { repo, service } = makeService();
  const intent = await service.requestUpload({
    uid: "user-1",
    purpose: "profile",
    mimeType: "image/png",
    fileSize: 100,
  });

  await assert.rejects(
    () => service.confirmUpload({ uid: "user-1", mediaId: intent.asset.id }),
    /not found in storage/,
  );

  const rows = repo.rows.get(intent.asset.id);
  assert.equal(rows?.status, "failed");
});

test("upload policy rejects unsupported types and oversized files", async () => {
  const { service } = makeService();

  await assert.rejects(
    () =>
      service.requestUpload({
        uid: "user-1",
        purpose: "profile",
        mimeType: "application/pdf",
        fileSize: 10,
      }),
    /Unsupported media type/,
  );

  await assert.rejects(
    () =>
      service.requestUpload({
        uid: "user-1",
        purpose: "profile",
        mimeType: "image/jpeg",
        fileSize: 4096,
      }),
    /upload limit/,
  );
});

test("only the owner can confirm or delete an asset", async () => {
  const { service } = makeService();
  const intent = await service.requestUpload({
    uid: "user-1",
    purpose: "profile",
    mimeType: "image/jpeg",
    fileSize: 64,
  });

  await assert.rejects(
    () => service.confirmUpload({ uid: "user-2", mediaId: intent.asset.id }),
    /Media asset not found/,
  );
  await assert.rejects(
    () => service.deleteAsset({ uid: "user-2", mediaId: intent.asset.id }),
    /Media asset not found/,
  );
});

test("place uploads require a curator allowlist entry", async () => {
  const { service } = makeService();

  await assert.rejects(
    () =>
      service.requestUpload({
        uid: "user-2",
        purpose: "place",
        mimeType: "image/jpeg",
        fileSize: 64,
      }),
    /curator/,
  );

  // Profile uploads stay available to ordinary authenticated users.
  const profile = await service.requestUpload({
    uid: "user-2",
    purpose: "profile",
    mimeType: "image/jpeg",
    fileSize: 64,
  });
  assert.equal(profile.asset.purpose, "profile");
});

test("refreshing an upload keeps the stored purpose", async () => {
  const { service } = makeService();
  const placeIntent = await service.requestUpload({
    uid: "user-1",
    purpose: "place",
    mimeType: "image/jpeg",
    fileSize: 64,
  });

  await assert.rejects(
    () =>
      service.requestUpload({
        uid: "user-1",
        purpose: "profile",
        mimeType: "image/jpeg",
        fileSize: 64,
        mediaId: placeIntent.asset.id,
      }),
    /purpose mismatch/,
  );
});

test("place assets cannot be confirmed or deleted by a non-curator owner", async () => {
  const { repo, service } = makeService();
  const id = "00000000-0000-4000-8000-0000000000aa";
  repo.rows.set(id, {
    id,
    object_key: "places/2026-11/legacy.jpg",
    bucket: "mock-bucket",
    mime_type: "image/jpeg",
    file_size: 64,
    visibility: "public",
    status: "pending",
    owner_id: "user-2",
    purpose: "place",
    user_id: null,
    group_id: null,
    outing_id: null,
    place_id: null,
    created_at: new Date(),
    updated_at: new Date(),
    verified_at: null,
    upload_expires_at: new Date(Date.now() + 60_000),
  });

  await assert.rejects(
    () => service.confirmUpload({ uid: "user-2", mediaId: id }),
    /curator/,
  );
  await assert.rejects(
    () => service.deleteAsset({ uid: "user-2", mediaId: id }),
    /curator/,
  );
  assert.equal(repo.rows.get(id)?.status, "pending");
});

test("profile delivery URL is signed/short-lived, place media is public", async () => {
  const { adapter, service } = makeService();

  const profileIntent = await service.requestUpload({
    uid: "user-1",
    purpose: "profile",
    mimeType: "image/jpeg",
    fileSize: 64,
  });
  adapter.store(profileIntent.asset.object_key, new Uint8Array(64), "image/jpeg");
  await service.confirmUpload({ uid: "user-1", mediaId: profileIntent.asset.id });

  const profileUrl = await service.getDeliveryUrl({
    uid: "user-1",
    mediaId: profileIntent.asset.id,
  });
  assert.match(profileUrl.url, /\/api\/media\/mock-download\//);
  assert.ok(profileUrl.expires_at);
  assert.equal(profileUrl.visibility, "private");

  // Another authenticated user may view profile avatars (product behavior).
  const otherUserUrl = await service.getDeliveryUrl({
    uid: "user-2",
    mediaId: profileIntent.asset.id,
  });
  assert.ok(otherUserUrl.url.length > 0);
});

test("public place delivery uses the CDN only when R2 and the CDN domain are configured", async () => {
  async function readyPlaceAsset(overrides: Parameters<typeof makeService>[0]) {
    const made = makeService(overrides);
    const intent = await made.service.requestUpload({
      uid: "user-1",
      purpose: "place",
      mimeType: "image/jpeg",
      fileSize: 64,
    });
    made.adapter.store(intent.asset.object_key, new Uint8Array(64), "image/jpeg");
    await made.service.confirmUpload({ uid: "user-1", mediaId: intent.asset.id });
    return { ...made, asset: intent.asset };
  }

  const mock = await readyPlaceAsset({});
  const mockUrl = await mock.service.getDeliveryUrl({
    uid: "user-1",
    mediaId: mock.asset.id,
  });
  assert.equal(mockUrl.visibility, "public");
  assert.match(mockUrl.url, /\/api\/media\/mock-download\//);
  assert.ok(mockUrl.expires_at);

  const r2NoCdn = await readyPlaceAsset({
    provider: "r2",
    publicBaseUrlConfigured: false,
  });
  const noCdnUrl = await r2NoCdn.service.getDeliveryUrl({
    uid: "user-1",
    mediaId: r2NoCdn.asset.id,
  });
  assert.doesNotMatch(noCdnUrl.url, /media\.example\.com/);
  assert.match(noCdnUrl.url, /\/api\/media\/mock-download\//);

  const r2Cdn = await readyPlaceAsset({
    provider: "r2",
    publicBaseUrl: "https://cdn.yalla.test",
    publicBaseUrlConfigured: true,
  });
  const cdnUrl = await r2Cdn.service.getDeliveryUrl({
    uid: "user-1",
    mediaId: r2Cdn.asset.id,
  });
  assert.equal(cdnUrl.visibility, "public");
  assert.equal(cdnUrl.expires_at, null);
  assert.equal(cdnUrl.url, `https://cdn.yalla.test/${r2Cdn.asset.object_key}`);
  assert.equal(
    r2Cdn.service.storageReferenceFor(r2Cdn.asset),
    `https://cdn.yalla.test/${r2Cdn.asset.object_key}`,
  );
});

test("resolveEntityImage links owned ready assets and rejects mismatched purposes", async () => {
  const { adapter, service } = makeService();

  // Groups/covers may be uploaded before the row exists (no entity id), which
  // is required for the create-group flow. Attach authorization is enforced by
  // the group create/update use cases when the reference is persisted.
  const groupIntent = await service.requestUpload({
    uid: "user-1",
    purpose: "group",
    mimeType: "image/jpeg",
    fileSize: 128,
    entityId: null,
  });
  assert.equal(groupIntent.asset.status, "pending");
  assert.equal(groupIntent.asset.visibility, "private");

  adapter.store(groupIntent.asset.object_key, new Uint8Array(128), "image/jpeg");
  await service.confirmUpload({ uid: "user-1", mediaId: groupIntent.asset.id });

  const linked = await service.resolveEntityImage({
    uid: "user-1",
    imageValue: buildMediaReference(groupIntent.asset.id),
    purpose: "group",
    link: { group_id: "group-1" },
  });
  assert.equal(linked, buildMediaReference(groupIntent.asset.id));

  const profileIntent = await service.requestUpload({
    uid: "user-1",
    purpose: "profile",
    mimeType: "image/jpeg",
    fileSize: 128,
  });
  adapter.store(profileIntent.asset.object_key, new Uint8Array(128), "image/jpeg");
  await service.confirmUpload({ uid: "user-1", mediaId: profileIntent.asset.id });

  const stored = await service.resolveEntityImage({
    uid: "user-1",
    imageValue: buildMediaReference(profileIntent.asset.id),
    purpose: "profile",
    link: { user_id: "user-1" },
  });
  assert.equal(stored, buildMediaReference(profileIntent.asset.id));

  await assert.rejects(
    () =>
      service.resolveEntityImage({
        uid: "user-1",
        imageValue: buildMediaReference(profileIntent.asset.id),
        purpose: "place",
      }),
    /cannot be used as place/,
  );

  await assert.rejects(
    () =>
      service.resolveEntityImage({
        uid: "user-2",
        imageValue: buildMediaReference(profileIntent.asset.id),
        purpose: "profile",
      }),
    /belongs to another user/,
  );
});

test("existing http(s) image URLs pass through unchanged", async () => {
  const { service } = makeService();
  const url = "https://cdn.example.com/existing/cover.jpg";
  assert.equal(
    await service.resolveEntityImage({ uid: "user-1", imageValue: url, purpose: "profile" }),
    url,
  );
  assert.equal(
    await service.resolveEntityImage({ uid: "user-1", imageValue: "", purpose: "profile" }),
    "",
  );
});

test("cleanup removes expired pending and failed rows plus objects", async () => {
  const { repo, service } = makeService();
  const pending = await service.requestUpload({
    uid: "user-1",
    purpose: "profile",
    mimeType: "image/jpeg",
    fileSize: 32,
  });
  repo.rows.get(pending.asset.id)!.upload_expires_at = new Date(Date.now() - 1000);

  const failed = await service.requestUpload({
    uid: "user-1",
    purpose: "profile",
    mimeType: "image/jpeg",
    fileSize: 32,
  });
  await service.confirmUpload({ uid: "user-1", mediaId: failed.asset.id }).catch(() => null);

  const { removed } = await service.cleanupExpired();
  assert.equal(removed, 2);
  assert.equal(repo.rows.size, 0);
});
