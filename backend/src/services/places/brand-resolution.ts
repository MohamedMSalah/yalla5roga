import type { Prisma } from "@prisma/client";
import { cleanText, normalizedName } from "./import-normalization.js";

export type BrandEvidence = { name: string; aliases: string[]; identity?: string };
/** Translation is evidence supplied by the source, never guessed transliteration. */
export function brandEvidence(raw: any): BrandEvidence | null {
  const tags = raw?.tags;
  const name = cleanText(tags?.brand ?? raw?.brand?.names?.primary, 100);
  if (!name || normalizedName(name).length < 2) return null;
  const wikidata = tags?.["brand:wikidata"] ?? raw?.brand?.wikidata;
  return { name, aliases: [name, tags?.["brand:ar"], tags?.["brand:en"],
    raw?.brand?.names?.common?.ar, raw?.brand?.names?.common?.en]
    .map((s) => cleanText(s, 100)).filter((s): s is string => !!s && normalizedName(s).length > 1),
    identity: typeof wikidata === "string" && /^Q[1-9][0-9]*$/.test(wikidata) ? `wikidata:${wikidata}` : undefined };
}

/** Called inside the branch transaction. Serialize the small brand lookup/write
 * section so overlapping aliases cannot create brands concurrently. */
export async function resolveBrand(tx: Prisma.TransactionClient, evidence: BrandEvidence | null,
  review: (code: string, details: any) => Promise<void>, branchNames: string[] = []): Promise<string | null> {
  if (!evidence) {
    const names = branchNames.map(normalizedName).filter(Boolean);
    if (!names.length) return null;
    const brands = await tx.place_brands.findMany({ where: { OR: [
      { normalized_name: { in: names } }, { aliases: { some: { normalized_name: { in: names } } } },
    ] }, take: 2 });
    if (brands.length === 1) return brands[0]!.id;
    if (brands.length > 1) await review("ambiguous_brand", { names, candidate_ids: brands.map((b) => b.id) });
    return null;
  }
  await tx.$executeRaw`SELECT pg_advisory_xact_lock(hashtext('places-brand-resolution'))`;
  const names = [...new Set(evidence.aliases.map(normalizedName))];
  const matches = await tx.place_brands.findMany({ where: { OR: [
    ...(evidence.identity ? [{ identity_key: evidence.identity }] : []),
    { normalized_name: { in: names } }, { aliases: { some: { normalized_name: { in: names } } } },
  ] }, take: 3 });
  const exact = evidence.identity ? matches.find((b) => b.identity_key === evidence.identity) : undefined;
  // A colliding alias never silently joins two identities, even with a stable ID.
  if (matches.length > 1 || (matches[0]?.identity_key && evidence.identity && matches[0].identity_key !== evidence.identity)) {
    await review("ambiguous_brand", { names, candidate_ids: matches.map((b) => b.id) });
    return exact?.id ?? null;
  }
  let brand = exact ?? matches[0];
  if (!brand) brand = await tx.place_brands.create({ data: {
    name: evidence.name, normalized_name: normalizedName(evidence.name), identity_key: evidence.identity,
  } });
  else if (evidence.identity && !brand.identity_key) {
    brand = await tx.place_brands.update({ where: { id: brand.id }, data: { identity_key: evidence.identity } });
  }
  await tx.place_brand_aliases.createMany({ data: evidence.aliases.map((name) => ({
    brand_id: brand.id, name, normalized_name: normalizedName(name),
  })), skipDuplicates: true });
  return brand.id;
}
