import { randomUUID, createHash } from "node:crypto";
import { createReadStream, readFileSync } from "node:fs";
import { resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { createInterface } from "node:readline";
import { spawn } from "node:child_process";
import { Prisma } from "@prisma/client";
import { prisma } from "../../config/database.js";
import { ConflictError } from "../../utils/errors.js";
import { categories, vibes } from "./taxonomy.js";
import { normalizeSource, RecordRejected } from "./import-normalization.js";
import { commonsImage, parseHours } from "./import-ancillary.js";
import { commitBatch, emptyCounters, planBatch, type Counters, type Diagnostic, type ImportRecord } from "./import-store.js";
import { notifyCatalogChanged } from "./catalog-notifications.js";

const ROOT = fileURLToPath(new URL("../../../", import.meta.url));
export type SyncOptions = {
  source?: "overture" | "osm"; city?: "cairo" | "giza"; dryRun?: boolean; limit?: number;
  manifest?: string; reuse?: boolean; resume?: string; batchSize?: number; signal?: AbortSignal;
};
export async function verifyPlacesTarget() {
  const [target] = await prisma.$queryRaw<any[]>`SELECT current_database() AS database,current_user AS role,current_schema() AS schema,current_setting('neon.project_id',true) AS project,current_setting('neon.branch_id',true) AS branch`;
  const expected = process.env.PLACES_EXPECTED_TARGET ? JSON.parse(process.env.PLACES_EXPECTED_TARGET) : {
    project: "rough-mountain-69896781", branch: "br-fragrant-heart-avfm4h2t", database: "neondb", schema: "public",
  };
  for (const key of ["project", "branch", "database", "schema"]) if (!expected[key] || target[key] !== expected[key])
    throw new Error(`Places database target mismatch: ${key}. Review PLACES_EXPECTED_TARGET before writes.`);
  return target;
}
export async function syncStatus(source = "overture") {
  const [lastSuccessful, lastRun, lease] = await Promise.all([
    prisma.place_sync_runs.findFirst({ where: { source, status: "success", complete: true, dry_run: false, coverage: { path: ["city"], equals: "all" } }, orderBy: { completed_at: "desc" } }),
    prisma.place_sync_runs.findFirst({ where: { source }, orderBy: { started_at: "desc" } }),
    prisma.place_sync_lock.findUnique({ where: { id: "catalog" } }),
  ]);
  return { source, last_successful_sync_at: lastSuccessful?.completed_at ?? null,
    automatic_sync_enabled: false, running: !!lease && lease.expires_at.getTime() > Date.now(), last_run: lastRun };
}
async function sha256(path: string) {
  const hash = createHash("sha256"); for await (const chunk of createReadStream(path)) hash.update(chunk);
  return hash.digest("hex");
}
async function acquire(options: SyncOptions) {
  if (options.manifest) return resolve(options.manifest);
  const python = process.env.PLACES_PYTHON ?? resolve(ROOT, process.platform === "win32" ? ".places-data/venv/Scripts/python.exe" : ".places-data/venv/bin/python");
  const child = spawn(python, [resolve(ROOT, "scripts/places_sources.py"), "--source", options.source ?? "overture", "--city", options.city ?? "all", ...(options.reuse ? ["--reuse"] : [])],
    { cwd: ROOT, stdio: ["ignore", "pipe", "inherit"], signal: options.signal });
  let result = ""; child.stdout.on("data", (chunk) => { result = (result + chunk).slice(-16000); });
  const code = await new Promise<number | null>((done, reject) => { child.once("error", reject); child.once("exit", done); });
  if (code !== 0) throw new Error(`Official source acquisition failed (${code})`);
  const path = result.trim().split(/\r?\n/).at(-1);
  if (!path) throw new Error("Source acquisition returned no manifest");
  return path;
}
async function seedTaxonomy() {
  await prisma.$transaction(async (tx) => {
    await tx.place_categories.createMany({ data: categories.map(([id, name_en, name_ar, group_id, icon, legacy_vibe], sort_order) => ({ id, name_en, name_ar, group_id, icon, legacy_vibe, sort_order })), skipDuplicates: true });
    await tx.vibes.createMany({ data: vibes.map(([id, name_en, name_ar, icon], sort_order) => ({ id, name_en, name_ar, icon, sort_order })), skipDuplicates: true });
  });
}
export async function synchronizePlaces(options: SyncOptions = {}) {
  const source = options.source ?? "overture";
  const batchSize = options.batchSize ?? Number(process.env.PLACES_BATCH_SIZE ?? 200);
  const minConfidence = Number(process.env.PLACES_MIN_CONFIDENCE ?? .7);
  const maxDistance = Number(process.env.PLACES_DUPLICATE_DISTANCE_METERS ?? 60);
  const absenceThreshold = Number(process.env.PLACES_ABSENCE_THRESHOLD ?? 3);
  if (!Number.isInteger(batchSize) || batchSize < 1 || batchSize > 1000 ||
      options.limit !== undefined && (!Number.isSafeInteger(options.limit) || options.limit < 1) ||
      !Number.isFinite(minConfidence) || minConfidence < 0 || minConfidence > 1 ||
      !Number.isFinite(maxDistance) || maxDistance < 1 || maxDistance > 200 ||
      !Number.isInteger(absenceThreshold) || absenceThreshold < 2) throw new Error("Invalid places import configuration");
  const target = await verifyPlacesTarget();
  console.log(JSON.stringify({ places_target_verified: target, source, dry_run: !!options.dryRun }));
  const token = randomUUID();
  let runId: string | undefined, heartbeat: ReturnType<typeof setInterval> | undefined, leaseLost = false;
  let counters = emptyCounters(), checkpoint = 0;
  try {
    if (!options.dryRun) {
      const acquired = await prisma.$executeRaw`INSERT INTO place_sync_lock(id,token,expires_at) VALUES ('catalog',${token}::uuid,now()+interval '10 minutes') ON CONFLICT(id) DO UPDATE SET token=EXCLUDED.token,expires_at=EXCLUDED.expires_at WHERE place_sync_lock.expires_at<now()`;
      if (!acquired) throw new ConflictError("A places synchronization is already running");
      heartbeat = setInterval(() => { void prisma.place_sync_lock.updateMany({ where: { id: "catalog", token }, data: { expires_at: new Date(Date.now() + 600000) } }).then((r) => { if (!r.count) leaseLost = true; }).catch(() => { leaseLost = true; }); }, 60000);
      heartbeat.unref();
      if (!options.resume) {
        await prisma.place_sync_runs.updateMany({ where: { status: "running" }, data: { status: "interrupted", completed_at: new Date(), complete: false } });
        runId = (await prisma.place_sync_runs.create({ data: { source, status: "running", coverage: { city: options.city ?? "all", source, stage: "acquisition" } } })).id;
      }
    }
    const manifestPath = await acquire(options);
    const manifest = JSON.parse(readFileSync(manifestPath, "utf8"));
    if (manifest.source !== source || manifest.city !== (options.city ?? "all") || !manifest.complete ||
      await sha256(manifest.path) !== manifest.sha256 || await sha256(manifest.boundary_path) !== manifest.boundary_sha256)
      throw new Error("Source manifest scope/completeness/checksum validation failed");
    const boundary = JSON.parse(readFileSync(manifest.boundary_path, "utf8"));
    const coverage = { source, city: options.city ?? "all", release: manifest.release, sha256: manifest.sha256, fetched_at: manifest.fetched_at,
      boundary_sha256: manifest.boundary_sha256, records: manifest.records, limit: options.limit ?? null, version: 2 };
    if (!options.dryRun) {
      await seedTaxonomy();
      if (options.resume) {
        const old = await prisma.place_sync_runs.findUniqueOrThrow({ where: { id: options.resume } });
        const oldCoverage = old.coverage as any;
        if (!["failed", "interrupted", "partial", "running"].includes(old.status) || old.source !== source || oldCoverage.sha256 !== manifest.sha256 || oldCoverage.city !== coverage.city || oldCoverage.limit !== coverage.limit)
          throw new Error("Resume requires the exact original source artifact, scope and limit");
        runId = old.id; counters = { ...emptyCounters(), ...(old.progress as any).counters }; checkpoint = (old.progress as any).last_line ?? 0;
        await prisma.place_sync_runs.update({ where: { id: runId }, data: { status: "running", completed_at: null } });
      } else {
        await prisma.place_sync_runs.update({ where: { id: runId! }, data: { coverage } });
      }
    }
    let shadow: any[] = [], line = 0;
    const diagnostics: Record<string, number> = {};
    const check = () => { options.signal?.throwIfAborted(); if (leaseLost) throw new Error("Places sync lease lost"); };
    const runData = (next: Counters, lastLine: number) => ({ processed_count: next.processed, imported_count: next.inserted, updated_count: next.updated,
      skipped_count: next.skipped, failed_count: next.failed, closed_count: next.closed, progress: { last_line: lastLine, counters: next, duplicates: next.duplicates, release: manifest.release } });
    async function processChunk(entries: { text: string; line: number }[]): Promise<void> {
      check();
      const records: ImportRecord[] = [], logs: Diagnostic[] = [], delta = emptyCounters(), rejectedIdentities: { source_id: string; source_type: string }[] = [];
      for (const entry of entries) {
        delta.processed++;
        let envelope: any;
        try {
          envelope = JSON.parse(entry.text);
          const normalized = normalizeSource(source, envelope, boundary, minConfidence);
          const record: ImportRecord = { ...normalized, line: entry.line };
          if (!parseHours(normalized.data.opening_hours).supported) logs.push({ level: "info", code: "hours_preserved_raw", source_id: normalized.data.source_id, details: { expression: normalized.data.opening_hours } });
          if (source === "osm" && normalized.raw.tags?.wikimedia_commons?.startsWith("File:")) {
            try { record.image = await commonsImage(normalized.raw.tags); }
            catch { logs.push({ level: "warn", code: "image_lookup_failed", source_id: normalized.data.source_id, details: {} }); }
          }
          records.push(record);
        } catch (error) {
          const code = error instanceof RecordRejected ? error.code : "invalid_source_record";
          delta.skipped++;
          const raw = envelope?.record;
          if (source === "overture" && typeof raw?.id === "string" && /^[0-9a-f-]{36}$/i.test(raw.id)) rejectedIdentities.push({ source_id: raw.id, source_type: "place" });
          if (source === "osm" && Number.isSafeInteger(raw?.id) && raw.id > 0 && ["node", "way", "relation"].includes(raw.type)) rejectedIdentities.push({ source_id: String(raw.id), source_type: raw.type });
          logs.push({ level: "warn", code, source_id: String(envelope?.record?.id ?? entry.line).slice(0, 160), details: error instanceof RecordRejected ? error.details : {} });
        }
      }
      const plan = await planBatch(records, maxDistance, options.dryRun ? shadow : []);
      delta.inserted = plan.writes.filter((w) => !w.existed).length; delta.updated = plan.writes.length - delta.inserted;
      delta.skipped += plan.skipped; delta.duplicates = plan.duplicates;
      delta.closed = plan.histories.filter((h) => h.old_status !== "new" && ["temporarily_closed", "permanently_closed"].includes(h.new_status)).length;
      if (plan.duplicates) logs.push({ level: "info", code: "duplicates_matched", details: { count: plan.duplicates } });
      const next = Object.fromEntries(Object.keys(counters).map((k) => [k, counters[k as keyof Counters] + delta[k as keyof Counters]])) as Counters;
      const lastLine = entries.at(-1)!.line;
      if (options.dryRun) { shadow = plan.shadow; counters = next; }
      else {
        for (let attempt = 0; ; attempt++) {
          try {
            await prisma.$transaction(async (tx) => {
              const lock = await tx.$queryRaw<any[]>`SELECT token,expires_at>now() AS valid FROM place_sync_lock WHERE id='catalog' FOR UPDATE`;
              if (lock[0]?.token !== token || !lock[0]?.valid) throw new Error("Places sync fencing check failed");
              const state = await tx.place_sync_runs.findUniqueOrThrow({ where: { id: runId! } });
              if (((state.progress as any).last_line ?? 0) >= lastLine) return;
              if (plan.aliases.length) await tx.$queryRaw`SELECT id FROM places WHERE id IN (${Prisma.join([...new Set(plan.aliases.map((p) => p.place_id))].map((id) => Prisma.sql`${id}::uuid`))}) FOR UPDATE`;
              await commitBatch(tx, plan, source, manifest.release, runId!);
              if (rejectedIdentities.length) await tx.place_source_records.updateMany({ where: { source, OR: rejectedIdentities }, data: { last_seen_at: new Date(), missing_count: 0 } });
              if (logs.length) await tx.place_sync_logs.createMany({ data: logs.map((l) => ({ ...l, run_id: runId! })) });
              await tx.place_sync_runs.update({ where: { id: runId! }, data: runData(next, lastLine) });
            }, { timeout: 120000, maxWait: 20000 });
            counters = next; break;
          } catch (error) {
            if (attempt < 3 && /P100[12]|P2024|P2034|closed|connect|timeout|deadlock/i.test(String(error))) {
              await new Promise((done) => setTimeout(done, 500 * 2 ** attempt)); continue;
            }
            if (entries.length > 1 && /P200[023]|constraint|too long/i.test(String(error))) {
              const middle = Math.ceil(entries.length / 2);
              await processChunk(entries.slice(0, middle)); await processChunk(entries.slice(middle)); return;
            }
            if (entries.length === 1 && /P200[023]|constraint|too long/i.test(String(error))) {
              const failed = { ...counters, processed: counters.processed + 1, failed: counters.failed + 1 };
              await prisma.$transaction(async (tx) => {
                const lock = await tx.$queryRaw<any[]>`SELECT token,expires_at>now() AS valid FROM place_sync_lock WHERE id='catalog' FOR UPDATE`;
                if (lock[0]?.token !== token || !lock[0]?.valid) throw new Error("Places sync fencing check failed");
                const state = await tx.place_sync_runs.findUniqueOrThrow({ where: { id: runId! } });
                if (((state.progress as any).last_line ?? 0) >= lastLine) return;
                await tx.place_sync_logs.create({ data: { run_id: runId!, level: "error", code: "record_write_failed", details: { line: lastLine, message: String(error).slice(0, 1000) } } });
                await tx.place_sync_runs.update({ where: { id: runId! }, data: runData(failed, lastLine) });
              }); counters = failed; return;
            }
            throw error;
          }
        }
      }
      for (const log of logs) diagnostics[log.code] = (diagnostics[log.code] ?? 0) + 1;
      console.log(JSON.stringify({ places_run: runId ?? "dry-run", source, line: lastLine, ...counters }));
    }
    let pending: { text: string; line: number }[] = [];
    for await (const text of createInterface({ input: createReadStream(manifest.path), crlfDelay: Infinity })) {
      line++; if (line <= checkpoint) continue; if (options.limit && line > options.limit) break;
      pending.push({ text, line }); if (pending.length >= batchSize) { await processChunk(pending); pending = []; }
    }
    if (pending.length) await processChunk(pending);
    check();
    const expectedRows = Object.values(manifest.records).reduce((sum: number, n: any) => sum + Number(n), 0);
    const complete = !options.limit && counters.failed === 0 && counters.processed === expectedRows;
    if (!options.limit && counters.processed !== expectedRows) throw new Error("Manifest record count mismatch");
    if (options.dryRun) return { status: "dry_run", source, complete, target, coverage, ...counters, diagnostics };
    await prisma.$transaction(async (tx) => {
      const lease = await tx.$queryRaw<any[]>`SELECT token,expires_at>now() AS valid FROM place_sync_lock WHERE id='catalog' FOR UPDATE`;
      if (lease[0]?.token !== token || !lease[0]?.valid) throw new Error("Places sync fencing check failed");
      const run = await tx.place_sync_runs.findUniqueOrThrow({ where: { id: runId! } });
      if (complete) {
        const regions = Object.keys(manifest.records);
        await tx.place_source_records.updateMany({ where: { source, region: { in: regions }, last_seen_at: { lt: run.started_at },
          OR: [{ last_absence_release: null }, { last_absence_release: { not: manifest.release } }] },
          data: { missing_count: { increment: 1 }, last_absence_release: manifest.release } });
        const missing = await tx.places.findMany({ where: { source, source_region: { in: regions }, manually_managed: false,
          status: { not: "permanently_closed" }, source_records: { some: { source, missing_count: { gte: absenceThreshold } } } } });
        for (const place of missing) if (place.status !== "unverified") {
          await tx.places.update({ where: { id: place.id }, data: { status: "unverified", missing_sync_count: absenceThreshold } });
          await tx.place_status_changes.create({ data: { place_id: place.id, run_id: runId, old_status: place.status, new_status: "unverified",
            evidence: { reason: "repeated_absence_review", threshold: absenceThreshold, release: manifest.release } } });
        }
        if (missing.length) await notifyCatalogChanged(tx);
      }
      await tx.place_sync_runs.update({ where: { id: runId! }, data: { status: complete ? "success" : "partial", complete, completed_at: new Date() } });
    }, { timeout: 120000 });
    return { run_id: runId, status: complete ? "success" : "partial", source, complete, ...counters, diagnostics };
  } catch (error) {
    if (runId) {
      await prisma.place_sync_runs.update({ where: { id: runId }, data: { status: options.signal?.aborted ? "interrupted" : "failed", complete: false, completed_at: new Date(), error_details: [error instanceof Error ? error.message : "Import failed"] } }).catch(() => undefined);
      await prisma.place_sync_logs.create({ data: { run_id: runId, level: "error", code: options.signal?.aborted ? "interrupted" : "run_failed", details: { message: error instanceof Error ? error.message : "Import failed" } } }).catch(() => undefined);
    }
    throw error;
  } finally {
    if (heartbeat) clearInterval(heartbeat);
    if (!options.dryRun) await prisma.place_sync_lock.deleteMany({ where: { id: "catalog", token } });
  }
}
