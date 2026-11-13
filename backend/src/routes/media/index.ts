import { Router } from "express";
import { authMiddleware } from "../../middleware/auth.middleware.js";
import { getMediaConfig } from "../../config/media.js";
import { getMockStorageAdapter } from "../../services/media/mock-storage.adapter.js";
import { NotFoundError, ValidationError } from "../../utils/errors.js";
import mediaRoutes from "./media.routes.js";

/**
 * Development-only storage routes backing the MockStorageAdapter. They exist
 * so the full direct-upload flow (presign → client PUT → confirm → signed
 * GET) works without Cloudflare credentials. Registered only while the media
 * provider resolves to `mock`; real R2 credentials remove them entirely.
 * Unauthenticated by design: presigned-style URLs cannot carry the Firebase
 * Bearer header the client sends to API routes, and the keys are unguessable.
 */
function createMockStorageRoutes(): Router {
  const adapter = getMockStorageAdapter(getMediaConfig().mockBaseUrl);
  const mockRoutes = Router();

  mockRoutes.put("/mock-upload/:key", (req, res, next) => {
    const chunks: Buffer[] = [];
    req.on("data", (chunk: Buffer) => chunks.push(chunk));
    req.on("end", () => {
      try {
        const key = decodeURIComponent(req.params.key as string);
        const bytes = new Uint8Array(Buffer.concat(chunks));
        adapter.store(key, bytes, (req.headers["content-type"] as string) ?? null);
        res.status(200).json({ success: true, data: { key, size: bytes.byteLength } });
      } catch (error) {
        next(new ValidationError((error as Error).message));
      }
    });
    req.on("error", next);
  });

  mockRoutes.get("/mock-download/:key", (req, res, next) => {
    try {
      const key = decodeURIComponent(req.params.key as string);
      const object = adapter.load(key);
      if (!object) throw new NotFoundError("Media object");
      res.setHeader("Content-Type", object.contentType ?? "application/octet-stream");
      res.setHeader("Cache-Control", "private, max-age=300");
      res.end(Buffer.from(object.bytes));
    } catch (error) {
      next(error);
    }
  });

  return mockRoutes;
}

const api = Router();
if (getMediaConfig().provider === "mock") {
  api.use(createMockStorageRoutes());
}
api.use(authMiddleware);
api.use(mediaRoutes);

const router = Router();
router.use("/api/media", api);

export default router;
