import { createHash } from "node:crypto";
import type { CatalogQuery } from "../../validators/places/catalog.validator.js";
import { ValidationError } from "../../utils/errors.js";
function scope(q: CatalogQuery) {
  const { cursor, offset, limit, ...filters } = q;
  return createHash("sha256").update(JSON.stringify(filters)).digest("hex").slice(0, 24);
}
export function decodeCatalogCursor(q: CatalogQuery): { id: string; value: string | number } | null {
  if (!q.cursor) return null;
  try {
    const parsed = JSON.parse(Buffer.from(q.cursor, "base64url").toString("utf8"));
    if (parsed.scope !== scope(q) || !/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(parsed.id) ||
      (q.sort === "distance" ? typeof parsed.value !== "number" || !Number.isFinite(parsed.value) :
        typeof parsed.value !== "string" || parsed.value.length > 100) ||
      q.sort === "updated" && !Number.isFinite(Date.parse(parsed.value))) throw new Error("Invalid cursor");
    return parsed;
  } catch { throw new ValidationError("Invalid cursor or changed query filters"); }
}
export function encodeCatalogCursor(q: CatalogQuery, row: any): string {
  return Buffer.from(JSON.stringify({ scope: scope(q), id: row.id, value: q.sort === "distance" ? Number(row.distance_km) : q.sort === "name" ? row.name : row.cursor_updated_at ?? new Date(row.updated_at).toISOString() })).toString("base64url");
}
