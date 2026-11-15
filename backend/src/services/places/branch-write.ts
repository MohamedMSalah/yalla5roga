import type { Prisma } from "@prisma/client";
import { resolveBrand } from "./brand-resolution.js";
import { duplicateMatch, normalizedName } from "./import-normalization.js";
import { ValidationError } from "../../utils/errors.js";
import type { CreatePlaceInput } from "../../types/places/place.types.js";

/** Curator creation shares source-first branch identity and conservative matching. */
export async function prepareBranch(tx: Prisma.TransactionClient, input: CreatePlaceInput) {
  const { brand: evidence, ...fields } = input;
  if (!Number.isFinite(fields.latitude) || !Number.isFinite(fields.longitude))
    throw new ValidationError("A physical branch requires latitude and longitude");
  await tx.$executeRaw`SELECT pg_advisory_xact_lock(hashtext('places-branch-create'))`;
  const source = fields.source ?? "manual", source_type = fields.source_type ?? "place";
  if (fields.source_id) {
    const identity = await tx.place_source_records.findUnique({ where: { source_source_type_source_id: { source, source_type, source_id: fields.source_id } } });
    const old = identity ? await tx.places.findUnique({ where: { id: identity.place_id } }) :
      await tx.places.findFirst({ where: { source, source_type, source_id: fields.source_id } });
    if (old) return { existing: old, fields };
  }
  const review = async (code: string, details: any) => {
    const run = await tx.place_sync_runs.create({ data: { source: "manual", status: "review", complete: false } });
    await tx.place_sync_logs.create({ data: { run_id: run.id, level: "warn", code, details } });
  };
  const threshold = Math.min(500, Math.max(1, Number(process.env.PLACES_DUPLICATE_DISTANCE_METERS) || 60));
  const bounds = threshold / 90000;
  const nearby = await tx.places.findMany({ where: {
    latitude: { gte: fields.latitude! - bounds, lte: fields.latitude! + bounds },
    longitude: { gte: fields.longitude! - bounds * 2, lte: fields.longitude! + bounds * 2 },
  }, take: 501 });
  const matches = nearby.filter((p) => duplicateMatch(fields, p, threshold));
  if (matches.length === 1 && nearby.length <= 500) return { existing: matches[0]!, fields };
  if (matches.length > 1 || nearby.length > 500) await review("ambiguous_branch", { candidate_ids: matches.map((p) => p.id) });
  let brand_id = fields.brand_id;
  if (brand_id && !await tx.place_brands.findUnique({ where: { id: brand_id }, select: { id: true } }))
    throw new ValidationError("Unknown place brand");
  if (brand_id === undefined) {
    brand_id = await resolveBrand(tx, evidence ? { ...evidence, aliases: [evidence.name, ...evidence.aliases] } : null, review);
    if (!evidence) {
      const names = [fields.name, fields.name_ar, fields.name_en].filter((s): s is string => !!s).map(normalizedName);
      const brands = await tx.place_brands.findMany({ where: { aliases: { some: { normalized_name: { in: names } } } }, take: 2 });
      if (brands.length === 1) brand_id = brands[0]!.id;
      if (brands.length > 1) await review("ambiguous_brand", { candidate_ids: brands.map((b) => b.id) });
    }
  }
  return { fields: { ...fields, brand_id, source, source_type }, existing: null };
}
