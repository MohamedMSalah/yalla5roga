import { randomUUID } from "node:crypto";
import { isDeepStrictEqual } from "node:util";
import { Prisma } from "@prisma/client";
import { prisma } from "../../config/database.js";
import { notifyCatalogChanged } from "./catalog-notifications.js";
import { duplicateMatch, type ImportedPlace } from "./import-normalization.js";
import { parseHours, sourcePrices } from "./import-ancillary.js";

export type ImportRecord = ImportedPlace & { image?: any; line: number };
export type Diagnostic = { level: string; code: string; source_id?: string; details: any };
export type Counters = { processed: number; inserted: number; updated: number; skipped: number; failed: number; duplicates: number; closed: number };
export const emptyCounters = (): Counters => ({ processed: 0, inserted: 0, updated: 0, skipped: 0, failed: 0, duplicates: 0, closed: 0 });

/** The same planning path is used by dry-runs and writes. Cross-source aliases
 * do not enrich/overwrite primary metadata: independently licensed evidence stays separate.
 */
export async function planBatch(records: ImportRecord[], maxDistance: number, shadow: any[] = []) {
  if (!records.length) return { writes: [], aliases: [], histories: [], duplicates: 0, skipped: 0, shadow };
  const source = records[0]!.data.source;
  const ids = records.map((r) => r.data.source_id);
  const [identities, direct, nearby] = await Promise.all([
    prisma.place_source_records.findMany({ where: { source, source_id: { in: ids } }, include: { place: true } }),
    prisma.places.findMany({ where: { source, source_id: { in: ids } } }),
    prisma.places.findMany({ where: {
      latitude: { gte: Math.min(...records.map((r) => r.data.latitude)) - .002, lte: Math.max(...records.map((r) => r.data.latitude)) + .002 },
      longitude: { gte: Math.min(...records.map((r) => r.data.longitude)) - .002, lte: Math.max(...records.map((r) => r.data.longitude)) + .002 },
    }, select: { id: true, source: true, source_type: true, source_id: true, name: true, name_ar: true, name_en: true,
      category_id: true, latitude: true, longitude: true, address: true, phone: true, website: true, manually_managed: true, status: true } }),
  ]);
  const identity = (p: any) => `${p.source_type}/${p.source_id}`;
  const exact = new Map<string, any>(direct.map((p) => [identity(p), p]));
  for (const p of identities) exact.set(identity(p), p.place);
  for (const p of shadow) if (p.source === source) exact.set(identity(p), p);
  const candidates: any[] = [...new Map([...nearby, ...shadow].map((p) => [p.id, p])).values()];
  const writes: any[] = [], aliases: any[] = [], histories: any[] = [];
  let duplicates = 0, skipped = 0;
  const seenBatch = new Set<string>();
  for (const record of records) {
    const p = record.data;
    const key = identity(p);
    if (seenBatch.has(key)) { skipped++; duplicates++; continue; }
    seenBatch.add(key);
    let old = exact.get(key);
    if (!old) {
      const matches = candidates.filter((candidate) => duplicateMatch(p, candidate, maxDistance));
      // Ambiguous matches are reviewed and kept separate, never arbitrarily merged.
      if (matches.length === 1) { old = matches[0]; duplicates++; }
    }
    const id = old?.id ?? randomUUID();
    const protectedRow = old && (old.manually_managed || old.source === "manual" || old.source !== p.source || identity(old) !== key);
    const unchanged = old && Object.entries(p).every(([k, v]) => isDeepStrictEqual(old[k], v && typeof v === "object" ? JSON.parse(JSON.stringify(v)) : v));
    const stale = old && p.source === "overture" && Number((old.source_tags as any)?.version ?? 0) > Number(p.source_tags?.version ?? 0) ||
      old && p.source === "osm" && Number((old.source_tags as any)?.meta?.version ?? 0) > Number(p.source_tags?.meta?.version ?? 0);
    if (protectedRow || unchanged || stale) skipped++;
    else {
      writes.push({ ...p, id, inferred: record.inferred, raw: record.raw, image: record.image, existed: !!old });
      if (!old || old.status !== p.status) histories.push({ place_id: id, old_status: old?.status ?? "new", new_status: p.status,
        evidence: { source: p.source, source_id: p.source_id, status: p.status, source_evidence: p.source_tags } });
    }
    aliases.push({ source: p.source, source_type: p.source_type, source_id: p.source_id, place_id: id,
      region: p.source_region, license: record.license, attribution: record.attribution, evidence: record.raw });
    const canonical = old ?? { ...p, id };
    exact.set(key, canonical);
    if (!old) candidates.push(canonical);
  }
  return { writes, aliases, histories, duplicates, skipped, shadow: candidates };
}

export async function commitBatch(tx: Prisma.TransactionClient, plan: Awaited<ReturnType<typeof planBatch>>, source: string, release: string, runId: string) {
  const records = plan.writes;
  if (records.length) {
    await tx.$executeRaw`INSERT INTO places(id,name,name_ar,name_en,description,category_id,latitude,longitude,address,city,district,area,phone,website,opening_hours,source,source_type,source_id,source_region,source_tags,status,vibe,last_seen_at,last_synced_at)
      SELECT x.id,x.name,x.name_ar,x.name_en,x.description,x.category_id,x.latitude,x.longitude,x.address,x.city,x.district,x.area,x.phone,x.website,x.opening_hours,x.source,x.source_type,x.source_id,x.source_region,x.source_tags,x.status,x.vibe::outing_vibe,now(),now()
      FROM jsonb_to_recordset(${JSON.stringify(records)}::jsonb) AS x(id uuid,name text,name_ar text,name_en text,description text,category_id text,latitude float8,longitude float8,address text,city text,district text,area text,phone text,website text,opening_hours text,source text,source_type text,source_id text,source_region text,source_tags jsonb,status text,vibe text)
      ON CONFLICT(source,source_type,source_id) DO UPDATE SET name=EXCLUDED.name,name_ar=EXCLUDED.name_ar,name_en=EXCLUDED.name_en,description=EXCLUDED.description,category_id=EXCLUDED.category_id,latitude=EXCLUDED.latitude,longitude=EXCLUDED.longitude,address=EXCLUDED.address,city=EXCLUDED.city,district=EXCLUDED.district,area=EXCLUDED.area,phone=EXCLUDED.phone,website=EXCLUDED.website,opening_hours=EXCLUDED.opening_hours,source_tags=EXCLUDED.source_tags,status=EXCLUDED.status,vibe=EXCLUDED.vibe,last_seen_at=now(),last_synced_at=now(),missing_sync_count=0,updated_at=now()
      WHERE NOT places.manually_managed`;
    // Row locks serialize curator changes. Only imported relations are replaced.
    const writable = (await tx.places.findMany({ where: { id: { in: records.map((r) => r.id) }, manually_managed: false }, select: { id: true } })).map((p) => p.id);
    const allowed = new Set(writable);
    await tx.place_vibes.deleteMany({ where: { place_id: { in: writable }, source } });
    const joins = records.filter((r) => allowed.has(r.id)).flatMap((r) => r.inferred.map((v: any) => ({ place_id: r.id, vibe_id: v.id, source, confidence: v.confidence, evidence: v.evidence })));
    if (joins.length) await tx.place_vibes.createMany({ data: joins, skipDuplicates: true });
    // Imported ancillary rows have explicit ownership, preserving all manual rows.
    await tx.place_hours.deleteMany({ where: { place_id: { in: writable }, source } });
    await tx.place_prices.deleteMany({ where: { place_id: { in: writable }, source } });
    await tx.place_images.deleteMany({ where: { place_id: { in: writable }, source } });
    const hours = records.filter((r) => allowed.has(r.id)).flatMap((r) => parseHours(r.opening_hours).rows.map((h) => ({ ...h, place_id: r.id, source, expression: r.opening_hours })));
    if (hours.length) await tx.place_hours.createMany({ data: hours, skipDuplicates: true });
    const prices = records.filter((r) => allowed.has(r.id)).flatMap((r) => sourcePrices(source === "osm" ? r.raw.tags ?? {} : {}).map((p) => ({ ...p, place_id: r.id, source })));
    if (prices.length) await tx.place_prices.createMany({ data: prices });
    const images = records.filter((r) => allowed.has(r.id) && r.image).map((r) => ({ ...r.image, place_id: r.id, source }));
    if (images.length) await tx.place_images.createMany({ data: images });
    const histories = plan.histories.filter((r) => allowed.has(r.place_id)).map((r) => ({ ...r, run_id: runId }));
    if (histories.length) await tx.place_status_changes.createMany({ data: histories });
    await notifyCatalogChanged(tx);
  }
  if (plan.aliases.length) {
    await tx.$executeRaw`INSERT INTO place_source_records(source,source_type,source_id,place_id,release,region,license,attribution,evidence,last_seen_at)
      SELECT x.source,x.source_type,x.source_id,x.place_id,${release},x.region,x.license,x.attribution,x.evidence,now()
      FROM jsonb_to_recordset(${JSON.stringify(plan.aliases)}::jsonb) AS x(source text,source_type text,source_id text,place_id uuid,region text,license text,attribution text,evidence jsonb)
      ON CONFLICT(source,source_type,source_id) DO UPDATE SET release=EXCLUDED.release,evidence=EXCLUDED.evidence,last_seen_at=now(),missing_count=0`;
    const owned = plan.aliases.filter((a) => !records.some((r) => r.id === a.place_id)).map((a) => a.place_id);
    if (owned.length) await tx.places.updateMany({ where: { id: { in: owned }, source, manually_managed: false }, data: { last_seen_at: new Date(), last_synced_at: new Date(), missing_sync_count: 0 } });
  }
}
