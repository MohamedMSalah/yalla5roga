import { z } from "zod";
const ids = z
  .string()
  .max(1500)
  .optional()
  .transform((s) => [
    ...new Set(
      (s ?? "")
        .split(",")
        .map((v) => v.trim())
        .filter(Boolean),
    ),
  ])
  .pipe(z.array(z.string().regex(/^[a-z0-9_]+$/)).max(50));
const coordinate = (min: number, max: number) =>
  z
    .preprocess(
      (v) => (typeof v === "string" && v.trim() !== "" ? Number(v) : v),
      z.number().finite().min(min).max(max),
    )
    .optional();
const baseCatalogQuerySchema = z
  .object({
    compact: z.literal("true").optional(),
    brand_id: z.uuid().optional(),
    details: z.literal("true").optional(),
    featured: z.enum(["true", "false"]).optional(),
    vibe: z.enum(["food", "activity", "outdoor", "movie"]).optional(),
    categories: ids,
    vibes: ids,
    search: z.string().trim().max(120).optional(),
    status: z
      .enum([
        "active",
        "temporarily_closed",
        "permanently_closed",
        "unverified",
      ])
      .default("active"),
    limit: z.coerce.number().int().min(1).max(100).default(50),
    offset: z.coerce.number().int().min(0).max(1000000).default(0),
    cursor: z.string().max(2048).optional(),
    lat: coordinate(-90, 90),
    lng: coordinate(-180, 180),
    radiusKm: z.coerce.number().finite().positive().max(100).optional(),
    bbox: z
      .string()
      .optional()
      .transform((s, ctx) => {
        if (!s) return undefined;
        const coordinates = s.split(",");
        const a = coordinates.map(Number);
        if (
          a.length !== 4 ||
          coordinates.some((value) => value.trim() === "") ||
          !a.every(Number.isFinite) ||
          Math.abs(a[0]!) > 180 ||
          Math.abs(a[2]!) > 180 ||
          a[1]! < -90 ||
          a[3]! > 90 ||
          a[0] === a[2] ||
          (a[0] === 180 && a[2] === -180) ||
          a[1]! >= a[3]!
        ) {
          ctx.addIssue({
            code: "custom",
            message: "bbox must be west,south,east,north",
          });
          return z.NEVER;
        }
        return a;
      }),
    sort: z.enum(["updated", "name", "distance", "id"]).default("updated"),
  })
  .superRefine((q, ctx) => {
    if (
      (q.lat === undefined) !== (q.lng === undefined) ||
      ((q.radiusKm !== undefined || q.sort === "distance") &&
        q.lat === undefined)
    )
      ctx.addIssue({
        code: "custom",
        message: "lat and lng required together for nearby/distance",
      });
    if (q.cursor && q.offset) ctx.addIssue({ code: "custom", message: "cursor and offset cannot be combined" });
  });
export const catalogQuerySchema = z.preprocess((value, ctx) => {
  if (!value || typeof value !== "object") return value;
  const q = { ...(value as Record<string, unknown>) };
  if (q.category !== undefined) {
    if (q.categories !== undefined && q.categories !== q.category) {
      ctx.addIssue({ code: "custom", message: "Conflicting category/categories" }); return z.NEVER;
    }
    q.categories = q.category;
  }
  const aliases = ["minLng", "minLat", "maxLng", "maxLat"];
  if (aliases.some((key) => q[key] !== undefined)) {
    if (!aliases.every((key) => typeof q[key] === "string" || typeof q[key] === "number") || q.bbox !== undefined) {
      ctx.addIssue({ code: "custom", message: "Supply all four min/max bounds, or bbox" }); return z.NEVER;
    }
    q.bbox = aliases.map((key) => q[key]).join(",");
  }
  return q;
}, baseCatalogQuerySchema);
export type CatalogQuery = z.infer<typeof catalogQuerySchema>;
