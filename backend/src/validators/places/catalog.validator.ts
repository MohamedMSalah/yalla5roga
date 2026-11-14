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
export const catalogQuerySchema = z
  .object({
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
    lat: coordinate(-90, 90),
    lng: coordinate(-180, 180),
    radiusKm: z.coerce.number().finite().positive().max(100).optional(),
    bbox: z
      .string()
      .optional()
      .transform((s, ctx) => {
        if (!s) return undefined;
        const a = s.split(",").map(Number);
        if (
          a.length !== 4 ||
          !a.every(Number.isFinite) ||
          a[0]! < -180 ||
          a[2]! > 180 ||
          a[1]! < -90 ||
          a[3]! > 90 ||
          a[0]! >= a[2]! ||
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
    sort: z.enum(["updated", "name", "distance"]).default("updated"),
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
  });
export type CatalogQuery = z.infer<typeof catalogQuerySchema>;
