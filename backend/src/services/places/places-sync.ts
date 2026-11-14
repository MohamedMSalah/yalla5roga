import { randomUUID } from "node:crypto";
import { prisma } from "../../config/database.js";
import { ConflictError } from "../../utils/errors.js";
import { notifyCatalogChanged } from "./catalog-notifications.js";
import {
  fetchOverpass,
  normalizeOsm,
  overpassQuery,
  REGIONS,
  TAG_KEYS,
  type NormalizedPlace,
  type OsmElement,
} from "./osm.js";

const WEEK_MS = 7 * 24 * 3600_000;
const LEASE_MS = 20 * 60_000;
export type SyncOptions = {
  dryRun?: boolean;
  limit?: number;
  dueOnly?: boolean;
};
export type SourceFetch = (
  region: string,
  key: string,
) => Promise<OsmElement[]>;

export async function syncStatus() {
  const [lastSuccessful, lastRun, lease] = await Promise.all([
    prisma.place_sync_runs.findFirst({
      where: { status: "success", complete: true, dry_run: false },
      orderBy: { completed_at: "desc" },
    }),
    prisma.place_sync_runs.findFirst({ orderBy: { started_at: "desc" } }),
    prisma.place_sync_lock.findUnique({ where: { id: "osm" } }),
  ]);
  const nextDueAt = lastSuccessful?.completed_at
    ? new Date(lastSuccessful.completed_at.getTime() + WEEK_MS)
    : null;
  return {
    last_successful_sync_at: lastSuccessful?.completed_at ?? null,
    next_due_at: nextDueAt,
    due: !nextDueAt || nextDueAt.getTime() <= Date.now(),
    running: !!lease && lease.expires_at.getTime() > Date.now(),
    last_run: lastRun,
  };
}

/** Lease/fencing and a single commit prevent failed runs from changing lifecycle state. */
export async function synchronizePlaces(
  options: SyncOptions = {},
  fetchSource: SourceFetch = (region, key) =>
    fetchOverpass(overpassQuery(region, key)),
) {
  if (
    options.limit !== undefined &&
    (!Number.isSafeInteger(options.limit) || options.limit < 1)
  )
    throw new Error("limit must be a positive integer; omit for full coverage");
  const token = randomUUID();
  const acquired = await prisma.$executeRaw`
    INSERT INTO place_sync_lock(id,token,expires_at) VALUES ('osm',${token}::uuid,now()+interval '20 minutes')
    ON CONFLICT(id) DO UPDATE SET token=EXCLUDED.token,expires_at=EXCLUDED.expires_at
    WHERE place_sync_lock.expires_at < now()`;
  if (!acquired)
    throw new ConflictError("A places synchronization is already running");
  let runId: string | undefined;
  try {
    if (options.dueOnly && !(await syncStatus()).due)
      return { status: "not_due" };
    await prisma.place_sync_runs.updateMany({
      where: { status: "running" },
      data: {
        status: "failed",
        completed_at: new Date(),
        failed_count: 1,
        error_details: ["Lease expired; recovered by next worker"],
      },
    });
    const run = await prisma.place_sync_runs.create({
      data: {
        id: token,
        status: "running",
        dry_run: !!options.dryRun,
        coverage: {
          regions: REGIONS,
          keys: TAG_KEYS,
          limit: options.limit ?? null,
          version: 1,
        },
      },
    });
    runId = run.id;
    const normalized = new Map<string, NormalizedPlace>();
    const seen = new Set<string>();
    const coverage: string[] = [];
    const snapshots: Record<string, string> = {};
    let skipped = 0,
      limited = false;
    // Every request must be complete. A validation limit explicitly disables absence processing.
    outer: for (const region of REGIONS) {
      let regionAccepted = 0;
      for (const key of TAG_KEYS) {
        const rows = await fetchSource(region, key);
        const renewed = await prisma.place_sync_lock.updateMany({
          where: { id: "osm", token, expires_at: { gt: new Date() } },
          data: { expires_at: new Date(Date.now() + LEASE_MS) },
        });
        if (!renewed.count) throw new Error("Places sync lease lost");
        coverage.push(`${region}:${key}`);
        const sourceTimestamp = (
          rows as OsmElement[] & { sourceTimestamp?: string }
        ).sourceTimestamp;
        if (sourceTimestamp) snapshots[`${region}:${key}`] = sourceTimestamp;
        for (const row of rows) {
          const identity = `${row.type}/${row.id}`;
          seen.add(identity);
          const place = normalizeOsm(row, region);
          if (!place) {
            skipped++;
            continue;
          }
          if (!normalized.has(identity)) regionAccepted++;
          const prior = normalized.get(identity);
          if (
            !prior ||
            prior.evidence.osm_version <= place.evidence.osm_version
          )
            normalized.set(identity, place);
          if (options.limit && normalized.size >= options.limit) {
            limited = true;
            break outer;
          }
          if (
            options.limit &&
            regionAccepted >= Math.ceil(options.limit / REGIONS.length)
          ) {
            limited = true;
            break;
          }
        }
        await prisma.place_sync_runs.update({
          where: { id: run.id },
          data: {
            progress: {
              coverage,
              snapshots,
              discovered: normalized.size,
              skipped,
            },
          },
        });
        if (process.env.PLACES_SYNC_QUIET !== "1")
          console.log(
            JSON.stringify({
              places_sync: run.id,
              coverage: coverage.at(-1),
              discovered: normalized.size,
              skipped,
            }),
          );
        if (
          options.limit &&
          regionAccepted >= Math.ceil(options.limit / REGIONS.length)
        )
          break;
      }
    }
    const complete =
      !limited &&
      !options.limit &&
      coverage.length === REGIONS.length * TAG_KEYS.length;
    const result = await prisma.$transaction(
      async (tx) => {
        const lease = await tx.$queryRaw<
          { token: string; valid: boolean }[]
        >`SELECT token,expires_at>now() AS valid FROM place_sync_lock WHERE id='osm' FOR UPDATE`;
        if (lease[0]?.token !== token || !lease[0].valid)
          throw new Error("Places sync fencing check failed");
        // Serialize curator overrides with source updates, mappings and evidence.
        await tx.$queryRaw`SELECT id FROM places WHERE source='osm' FOR UPDATE`;
        const existing = await tx.places.findMany({
          where: { source: "osm" },
          include: { place_vibes: true },
        });
        const byIdentity = new Map(
          existing.map((p) => [`${p.source_type}/${p.source_id}`, p]),
        );
        const taxonomy = new Set(
          (
            await tx.place_categories.findMany({
              where: { is_active: true },
              select: { id: true },
            })
          ).map((c) => c.id),
        );
        const activeVibes = new Set(
          (
            await tx.vibes.findMany({
              where: { is_active: true },
              select: { id: true },
            })
          ).map((v) => v.id),
        );
        const records: any[] = [],
          histories: any[] = [],
          joins: { place_id: string; vibe_id: string; source: string }[] = [];
        let imported = 0,
          updated = 0,
          closed = 0;
        const now = new Date();
        for (const place of normalized.values()) {
          const old = byIdentity.get(`${place.source_type}/${place.source_id}`);
          const oldVersion = Number(
            (old?.source_tags as any)?.meta?.version ?? 0,
          );
          if (
            old?.manually_managed ||
            oldVersion > place.evidence.osm_version ||
            !taxonomy.has(place.category_id)
          ) {
            skipped++;
            continue;
          }
          const { vibes, evidence, ...data } = place;
          const id = old?.id ?? randomUUID();
          if (old) updated++;
          else imported++;
          if (old?.status !== data.status && data.status !== "active") closed++;
          if (!old || old.status !== data.status)
            histories.push({
              place_id: id,
              run_id: run.id,
              old_status: old?.status ?? "new",
              new_status: data.status,
              evidence,
            });
          records.push({ ...data, id });
          for (const vibe of vibes)
            if (activeVibes.has(vibe))
              joins.push({ place_id: id, vibe_id: vibe, source: "osm" });
        }
        if (!options.dryRun) {
          for (let offset = 0; offset < records.length; offset += 250) {
            const batch = records.slice(offset, offset + 250);
            // Parameterized bulk upsert keeps a thousand-row import to a handful of DB round trips.
            await tx.$executeRaw`INSERT INTO places(id,name,name_ar,name_en,description,category_id,latitude,longitude,address,city,district,area,phone,website,opening_hours,source,source_type,source_id,source_region,source_tags,status,vibe,last_seen_at,last_synced_at,missing_sync_count)
            SELECT x.id,x.name,x.name_ar,x.name_en,x.description,x.category_id,x.latitude,x.longitude,x.address,x.city,x.district,x.area,x.phone,x.website,x.opening_hours,'osm',x.source_type,x.source_id,x.source_region,x.source_tags,x.status,x.vibe::outing_vibe,${now},${now},0
            FROM jsonb_to_recordset(${JSON.stringify(batch)}::jsonb) AS x(id uuid,name text,name_ar text,name_en text,description text,category_id text,latitude float8,longitude float8,address text,city text,district text,area text,phone text,website text,opening_hours text,source_type text,source_id text,source_region text,source_tags jsonb,status text,vibe text)
            ON CONFLICT(source,source_type,source_id) DO UPDATE SET
              name=EXCLUDED.name,name_ar=EXCLUDED.name_ar,name_en=EXCLUDED.name_en,description=EXCLUDED.description,category_id=EXCLUDED.category_id,latitude=EXCLUDED.latitude,longitude=EXCLUDED.longitude,address=EXCLUDED.address,city=EXCLUDED.city,district=EXCLUDED.district,area=EXCLUDED.area,phone=EXCLUDED.phone,website=EXCLUDED.website,opening_hours=EXCLUDED.opening_hours,source_tags=EXCLUDED.source_tags,source_region=EXCLUDED.source_region,status=EXCLUDED.status,vibe=EXCLUDED.vibe,last_seen_at=EXCLUDED.last_seen_at,last_synced_at=EXCLUDED.last_synced_at,missing_sync_count=0,updated_at=now()
            WHERE NOT places.manually_managed`;
          }
          const ids = records.map((p) => p.id);
          if (ids.length) {
            await tx.place_vibes.deleteMany({
              where: { place_id: { in: ids }, source: "osm" },
            });
            if (joins.length)
              await tx.place_vibes.createMany({
                data: joins,
                skipDuplicates: true,
              });
          }
          if (complete) {
            const missing = existing.filter(
              (p) =>
                !p.manually_managed &&
                (REGIONS as readonly string[]).includes(
                  p.source_region ?? "",
                ) &&
                !seen.has(`${p.source_type}/${p.source_id}`),
            );
            for (const old of missing) {
              const status =
                old.missing_sync_count + 1 >= 3 &&
                old.status !== "permanently_closed"
                  ? "unverified"
                  : old.status;
              if (status !== old.status)
                histories.push({
                  place_id: old.id,
                  run_id: run.id,
                  old_status: old.status,
                  new_status: status,
                  evidence: {
                    reason: "missing_in_three_complete_cycles",
                    coverage,
                    snapshots,
                    missing_count: old.missing_sync_count + 1,
                  },
                });
            }
            if (missing.length) {
              await tx.places.updateMany({
                where: { id: { in: missing.map((p) => p.id) } },
                data: {
                  missing_sync_count: { increment: 1 },
                  last_synced_at: now,
                },
              });
              await tx.places.updateMany({
                where: {
                  id: { in: missing.map((p) => p.id) },
                  missing_sync_count: { gte: 3 },
                  status: { not: "permanently_closed" },
                },
                data: { status: "unverified" },
              });
            }
            // Seen but unusable records reset absence streaks without changing lifecycle state.
            const seenIds = existing
              .filter(
                (p) =>
                  !p.manually_managed &&
                  seen.has(`${p.source_type}/${p.source_id}`),
              )
              .map((p) => p.id);
            if (seenIds.length)
              await tx.places.updateMany({
                where: { id: { in: seenIds } },
                data: {
                  missing_sync_count: 0,
                  last_seen_at: now,
                  last_synced_at: now,
                },
              });
          }
          if (histories.length)
            await tx.place_status_changes.createMany({ data: histories });
          await notifyCatalogChanged(tx);
        }
        return tx.place_sync_runs.update({
          where: { id: run.id },
          data: {
            status: options.dryRun
              ? "dry_run"
              : complete
                ? "success"
                : "partial",
            completed_at: now,
            complete,
            imported_count: imported,
            updated_count: updated,
            closed_count: closed,
            skipped_count: skipped,
            progress: { coverage, snapshots, discovered: normalized.size },
          },
        });
      },
      { timeout: 180_000, maxWait: 10_000 },
    );
    return result;
  } catch (error) {
    if (runId)
      await prisma.place_sync_runs.updateMany({
        where: { id: runId, status: "running" },
        data: {
          status: "failed",
          completed_at: new Date(),
          failed_count: 1,
          error_details: [
            error instanceof Error ? error.message : "Unknown sync failure",
          ],
        },
      });
    throw error;
  } finally {
    await prisma.place_sync_lock.deleteMany({ where: { id: "osm", token } });
  }
}
