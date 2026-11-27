import { createHash } from "node:crypto";
import type { CatalogQuery } from "../../validators/places/catalog.validator.js";
import { ValidationError } from "../../utils/errors.js";
function scope(q: CatalogQuery) {
  const { cursor, offset, limit, ...filters } = q;
  // Keep tokens from before rating filters valid for the same default query.
  const { includeUnrated, ...rest } = filters;
  return createHash("sha256").update(JSON.stringify(includeUnrated ? rest : filters)).digest("hex").slice(0, 24);
}
type CatalogCursor = {
  id: string;
  value: string | number;
  rating?: { count: number; version: string };
};
export function decodeCatalogCursor(q: CatalogQuery): CatalogCursor | null {
  if (!q.cursor) return null;
  try {
    const parsed = JSON.parse(Buffer.from(q.cursor, "base64url").toString("utf8"));
    if (parsed.scope !== scope(q) || !/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(parsed.id) ||
      (q.sort === "distance" ? typeof parsed.value !== "number" || !Number.isFinite(parsed.value) :
        typeof parsed.value !== "string" || parsed.value.length > 100) ||
      q.sort === "updated" && !Number.isFinite(Date.parse(parsed.value))) throw new Error("Invalid cursor");
    if (q.sort === "top_rated" && (!/^[0-5](?:\.\d+)?$/.test(parsed.value) ||
      !Number.isInteger(parsed.rating?.count) || parsed.rating.count < 0 ||
      parsed.rating.count > 2147483647 || typeof parsed.rating.version !== "string" ||
      !/^\d+:\d+:\d+:-?\d{1,40}$/.test(parsed.rating.version))) throw new Error("Invalid rating cursor");
    return { id: parsed.id, value: parsed.value, ...(q.sort === "top_rated" && { rating: parsed.rating }) };
  } catch { throw new ValidationError("Invalid cursor or changed query filters"); }
}
export function encodeCatalogCursor(q: CatalogQuery, row: any): string {
  const rating = q.sort === "top_rated"
    ? { count: row.ranking_count, version: row.ranking_version }
    : undefined;
  const value = rating ? row.cursor_rating_score : q.sort === "id" ? row.id :
    q.sort === "distance" ? Number(row.distance_km) : q.sort === "name" ? row.name :
    row.cursor_updated_at ?? new Date(row.updated_at).toISOString();
  return Buffer.from(JSON.stringify({ scope: scope(q), id: row.id, value, rating })).toString("base64url");
}

export type ChangeCursor = { revision: string; kind: string; id: string };
const start: ChangeCursor = { revision: "0", kind: "", id: "" };

export function encodeChangeCursor(cursor: ChangeCursor) {
  return Buffer.from(JSON.stringify(cursor)).toString("base64url");
}

export function decodeChangeCursor(token: string | undefined): ChangeCursor {
  if (!token) return start;
  const value = JSON.parse(Buffer.from(token, "base64url").toString("utf8"));
  if (!value || typeof value.revision !== "string" ||
      !/^\d{1,20}$/.test(value.revision) ||
      BigInt(value.revision) > 18446744073709551615n ||
      !["", "place", "brand", "category", "vibe"].includes(value.kind) ||
      typeof value.id !== "string" || !/^[a-zA-Z0-9_-]{0,64}$/.test(value.id)) {
    throw new Error("Invalid catalog cursor");
  }
  return value;
}
