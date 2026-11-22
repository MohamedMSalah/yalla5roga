import { prisma } from "../src/config/database.js";
import { MediaService } from "../src/services/media/media.service.js";
import { validateProductionConfig } from "../src/config/deployment.js";

try {
  const [uid, source, ...extra] = process.argv.slice(2);
  if (!uid || !source || extra.length) throw new Error("Supply a curator UID and authorized source URL.");
  if (process.env.NODE_ENV === "production") validateProductionConfig();
  const media = new MediaService();
  const asset = await media.importCatalogImage(uid, source);
  console.log(media.storageReferenceFor(asset));
} catch {
  console.error("Catalog image import failed. Check the selected R2 and database targets, curator UID, source allowlist, license and image.");
  process.exitCode = 1;
} finally {
  await prisma.$disconnect();
}
