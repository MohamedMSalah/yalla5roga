import { parsePhoneNumberFromString } from "libphonenumber-js";
import { categories } from "./taxonomy.js";
import { normalizeOsm } from "./osm.js";
import { classifyOverture } from "./overture-taxonomy.js";
import { PlaceVibeClassifier } from "./place-vibe-classifier.js";

export const CATALOG_ATTRIBUTION = "Overture Maps Foundation (CDLA Permissive 2.0 / source licenses); © OpenStreetMap contributors (ODbL 1.0)";
export const OVERTURE_LICENSES = new Set(["CDLA-Permissive-2.0", "CC0-1.0", "Apache-2.0"]);
export function cleanText(value: unknown, max = 1000): string | null {
  return typeof value === "string" ? value.normalize("NFC").replace(/[\u0000-\u001f\u007f]/g, " ").replace(/\s+/g, " ").trim().slice(0, max) || null : null;
}
export function normalizedName(value: string): string {
  return value.normalize("NFKD").toLowerCase().replace(/[\u0300-\u036f\u064b-\u065f\u0670\u0640]/g, "")
    .replace(/[أإآٱ]/g, "ا").replace(/ى/g, "ي").replace(/[^\p{L}\p{N}]+/gu, " ").trim();
}
export function normalizedPhone(value: unknown): string | null {
  const text = cleanText(value, 100);
  if (!text) return null;
  return text.split(/[;,]/).map((part) => parsePhoneNumberFromString(part.trim(), "EG"))
    .find((phone) => phone?.isValid())?.number ?? null;
}
export function safeWebsite(value: unknown): string | null {
  if (typeof value !== "string" || !value.trim()) return null;
  try {
    const url = new URL(value.includes("://") ? value : `https://${value}`);
    return ["https:", "http:"].includes(url.protocol) && !url.username && !url.password &&
      url.hostname.includes(".") ? url.toString().slice(0, 2048) : null;
  } catch { return null; }
}

type Position = number[];
function inRing(x: number, y: number, ring: Position[]): boolean {
  let inside = false;
  for (let i = 0, j = ring.length - 1; i < ring.length; j = i++) {
    const [a, b] = ring[i]!, [c, d] = ring[j]!;
    if (a === undefined || b === undefined || c === undefined || d === undefined) continue;
    if (Math.abs((x - a) * (d - b) - (y - b) * (c - a)) < 1e-10 &&
      x >= Math.min(a, c) && x <= Math.max(a, c) && y >= Math.min(b, d) && y <= Math.max(b, d)) return true;
    if ((b > y) !== (d > y) && x < (c - a) * (y - b) / (d - b) + a) inside = !inside;
  }
  return inside;
}
export function insideBoundary(lng: number, lat: number, geometry: any): boolean {
  const polygons = geometry?.type === "Polygon" ? [geometry.coordinates] : geometry?.type === "MultiPolygon" ? geometry.coordinates : [];
  return polygons.some((rings: Position[][]) => rings.length && inRing(lng, lat, rings[0]!) && !rings.slice(1).some((ring) => inRing(lng, lat, ring)));
}

export class RecordRejected extends Error {
  constructor(readonly code: string, readonly details: Record<string, unknown> = {}) { super(code); }
}
export function normalizeSource(source: "osm" | "overture", envelope: any, boundary: any, minConfidence: number) {
  const raw = envelope.record;
  const region = envelope.region;
  if (!["EG-C", "EG-GZ"].includes(region)) throw new RecordRejected("invalid_region");
  let data: any, secondary: string[] = [], license: string, attribution: string;
  if (source === "osm") {
    data = normalizeOsm(raw, region);
    if (!data) throw new RecordRejected("invalid_or_unmapped_osm", { tags: raw?.tags ?? {} });
    delete data.vibes;
    delete data.evidence;
    license = "ODbL-1.0";
    attribution = "© OpenStreetMap contributors — https://www.openstreetmap.org/copyright";
    if (raw.tags?.access === "private") throw new RecordRejected("private_access");
  } else {
    if (typeof raw?.id !== "string" || !/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(raw.id))
      throw new RecordRejected("invalid_source_id");
    const status = raw.operating_status === "permanently_closed" ? "permanently_closed" :
      raw.operating_status === "temporarily_closed" ? "temporarily_closed" : raw.operating_status == null || raw.operating_status === "open" ? "active" : "unverified";
    if (raw.confidence != null && (typeof raw.confidence !== "number" || !Number.isFinite(raw.confidence) || raw.confidence < 0 || raw.confidence > 1))
      throw new RecordRejected("invalid_confidence");
    if (status !== "permanently_closed" && (raw.confidence == null || raw.confidence < minConfidence))
      throw new RecordRejected("low_confidence", { confidence: raw.confidence ?? null });
    const mapped = classifyOverture(raw.basic_category, raw.taxonomy ?? {});
    if (!mapped.primary) throw new RecordRejected("unmapped_overture_taxonomy", { basic_category: raw.basic_category, taxonomy: raw.taxonomy });
    secondary = mapped.secondary;
    const sources: any[] = Array.isArray(raw.sources) ? raw.sources : [];
    // Current sources must supply explicit known licenses. Unknown restrictions fail closed.
    if (!sources.length || sources.some((s) => !OVERTURE_LICENSES.has(s.license)))
      throw new RecordRejected("unreviewed_source_license", { sources });
    license = [...new Set(sources.map((s) => s.license))].sort().join(",");
    attribution = `Overture Maps Foundation; ${[...new Set(sources.map((s) => s.dataset))].join(", ")}; https://docs.overturemaps.org/attribution/`;
    const address = raw.addresses?.find((a: any) => a.country === "EG") ?? raw.addresses?.[0];
    if (address?.country && address.country !== "EG") throw new RecordRejected("non_egypt_address");
    data = {
      source, source_type: "place", source_id: raw.id, source_region: region,
      name: cleanText(raw.names?.primary, 100), name_ar: cleanText(raw.names?.common?.ar, 100), name_en: cleanText(raw.names?.common?.en, 100),
      latitude: raw.latitude, longitude: raw.longitude, category_id: mapped.primary,
      address: cleanText(address?.freeform), city: cleanText(address?.locality, 100), district: null,
      area: cleanText(address?.locality, 100) ?? "", phone: raw.phones?.[0] ?? null,
      website: raw.websites?.[0] ?? null, description: "", opening_hours: null, status,
      source_tags: { taxonomy: raw.taxonomy, basic_category: raw.basic_category, confidence: raw.confidence, operating_status: raw.operating_status ?? null, version: raw.version, sources },
    };
  }
  if (!data.name || data.name.length < 2 || !normalizedName(data.name)) throw new RecordRejected("invalid_name");
  if (!Number.isFinite(data.latitude) || !Number.isFinite(data.longitude) || Math.abs(data.latitude) > 90 || Math.abs(data.longitude) > 180)
    throw new RecordRejected("invalid_coordinates");
  const geometry = boundary.features.find((f: any) => f.properties.region === region)?.geometry;
  if (!insideBoundary(data.longitude, data.latitude, geometry)) throw new RecordRejected("outside_admin_boundary");
  const category = categories.find((c) => c[0] === data.category_id);
  if (!category) throw new RecordRejected("unknown_category");
  data.vibe = category[5];
  data.phone = normalizedPhone(data.phone);
  data.website = safeWebsite(data.website);
  data.source_tags = JSON.parse(JSON.stringify({ ...data.source_tags, classification_version: 1 }));
  const inferred = new PlaceVibeClassifier().classify(data.category_id, source === "osm" ? raw.tags : {}, secondary);
  return { data, inferred, license, attribution, raw };
}
export type ImportedPlace = ReturnType<typeof normalizeSource>;

export function distanceMeters(a: any, b: any): number {
  const rad = Math.PI / 180;
  const q = Math.sin((a.latitude - b.latitude) * rad / 2) ** 2 + Math.cos(a.latitude * rad) * Math.cos(b.latitude * rad) * Math.sin((a.longitude - b.longitude) * rad / 2) ** 2;
  return 12742017.6 * Math.asin(Math.min(1, Math.sqrt(q)));
}
export function duplicateMatch(a: any, b: any, maxDistance = 60): boolean {
  if (!a.category_id || !b.category_id || !Number.isFinite(b.latitude) || !Number.isFinite(b.longitude) || distanceMeters(a, b) > maxDistance) return false;
  const equivalent = (category: string) => ({ coffee_shops: "cafes", gaming_centers: "arcades" }[category] ?? category);
  if (equivalent(a.category_id) !== equivalent(b.category_id)) return false;
  const names = (p: any) => [p.name, p.name_ar, p.name_en].filter(Boolean).map(normalizedName);
  const sameName = names(a).some((n) => names(b).includes(n));
  const samePhone = !!a.phone && a.phone === b.phone;
  const sameWebsite = !!a.website && !!b.website && a.website.replace(/\/$/, "") === b.website.replace(/\/$/, "");
  const sameAddress = !!a.address && normalizedName(a.address).length >= 8 && normalizedName(a.address) === normalizedName(b.address ?? "");
  const house = (value: string | null) => /(?:^|\s)(\d+[a-z]?)(?:\s|$)/i.exec(normalizedName(value ?? ""))?.[1];
  if (house(a.address) && house(b.address) && house(a.address) !== house(b.address)) return false;
  // Close branches still require independent evidence; coordinates alone never match.
  return sameName && (samePhone || sameWebsite || sameAddress);
}
