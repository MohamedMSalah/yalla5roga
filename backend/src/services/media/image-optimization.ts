import sharp from "sharp";
import { AppError, ValidationError } from "../../utils/errors.js";

export const imageMimeTypes = ["image/jpeg", "image/png", "image/webp", "image/gif"];
const maxInputPixels = 24_000_000;
let active = 0;

function setting(name: string, fallback: number, min: number, max: number) {
  const value = Number(process.env[name]);
  return Number.isSafeInteger(value) && value >= min && value <= max ? value : fallback;
}

function sniff(bytes: Buffer) {
  if (bytes[0] === 0xff && bytes[1] === 0xd8 && bytes[2] === 0xff) return "image/jpeg";
  if (bytes.subarray(0, 8).equals(Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]))) return "image/png";
  if (bytes.toString("ascii", 0, 4) === "RIFF" && bytes.toString("ascii", 8, 12) === "WEBP") return "image/webp";
  if (["GIF87a", "GIF89a"].includes(bytes.toString("ascii", 0, 6))) return "image/gif";
  return undefined;
}

function isCleanWebp(bytes: Buffer): boolean {
  if (bytes.length < 20 || bytes.readUInt32LE(4) !== bytes.length - 8) return false;
  let offset = 12;
  while (offset + 8 <= bytes.length) {
    if (!["VP8 ", "VP8L", "VP8X", "ALPH"].includes(bytes.toString("ascii", offset, offset + 4))) return false;
    const size = bytes.readUInt32LE(offset + 4);
    offset += 8 + size + size % 2;
  }
  return offset === bytes.length;
}

export async function optimizeImage(bytes: Buffer, declaredType: string, maxBytes: number) {
  if (!bytes.length || bytes.length > maxBytes || sniff(bytes) !== declaredType) {
    throw new ValidationError("Uploaded image does not match its declared size or format");
  }
  if (active >= 2) throw new AppError(503, "Image validation busy; try again");
  active++;
  const maxEdge = setting("IMAGE_UPLOAD_MAX_EDGE", 1600, 256, 2400);
  const target = Math.min(maxBytes, setting("IMAGE_UPLOAD_TARGET_BYTES", 350 * 1024, 32 * 1024, 2 * 1024 * 1024));
  const quality = setting("IMAGE_UPLOAD_QUALITY", 80, 65, 90);
  try {
    const image = sharp(bytes, { animated: true, limitInputPixels: maxInputPixels, failOn: "warning" }).timeout({ seconds: 8 });
    const { width, height, pageHeight, format = "", pages = 1, orientation = 1 } = await image.metadata();
    const frameHeight = pageHeight ?? height;
    if (!width || !frameHeight || width * frameHeight * pages > maxInputPixels || pages > 60 ||
      `image/${format}` !== declaredType || (pages > 1 && (orientation !== 1 || !["gif", "webp"].includes(format))) ||
      (format === "jpeg" && bytes.readUInt16BE(bytes.length - 2) !== 0xffd9)) {
      throw new ValidationError("Unsupported image dimensions or animation");
    }
    if (format === "webp" && pages === 1 && bytes.length <= target && Math.max(width, frameHeight) <= maxEdge &&
      orientation === 1 && isCleanWebp(bytes)) {
      // Validate pixel data even when the original compressed representation is kept.
      await image.clone().raw().toBuffer();
      return { bytes, mimeType: "image/webp" };
    }
    let output: Buffer | undefined;
    for (const [edge, compression] of [[maxEdge, quality], [maxEdge, Math.max(65, quality - 9)],
      [Math.floor(maxEdge * 0.75), 70], [Math.floor(maxEdge * 0.55), 65]]) {
      const transform = image.clone();
      if (pages === 1) transform.rotate();
      output = await transform.resize(edge, edge, { fit: "inside", withoutEnlargement: true })
        .webp({ quality: compression, effort: 3 }).toBuffer();
      if (output.length <= target) return { bytes: output, mimeType: "image/webp" };
    }
    if (output && output.length <= maxBytes) return { bytes: output, mimeType: "image/webp" };
    throw new ValidationError("Optimized image exceeds the upload limit");
  } catch (error) {
    if (error instanceof ValidationError) throw error;
    throw new ValidationError("Image could not be decoded safely");
  } finally {
    active--;
  }
}
