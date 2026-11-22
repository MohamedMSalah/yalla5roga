import { prisma } from "../config/database.js";
import {
  synchronizePlaces,
  syncStatus,
} from "../services/places/places-sync.js";
const args = process.argv.slice(2);
const stop = new AbortController();
process.once("SIGINT", () => stop.abort(new Error("Interrupted by operator")));
process.once("SIGTERM", () => stop.abort(new Error("Worker termination requested")));
try {
  const flags = new Set(["dry-run", "status", "initial", "sync", "reuse"]);
  const values = new Set(["source", "city", "limit", "batch-size", "manifest", "resume"]);
  const parsed: Record<string, string> = {};
  for (let i = 0; i < args.length; i++) {
    const [key, inline] = args[i]!.replace(/^--/, "").split("=", 2);
    if (!args[i]!.startsWith("--") || !key || (!flags.has(key) && !values.has(key))) throw new Error(`Unknown argument ${args[i]}`);
    if (flags.has(key)) { if (inline !== undefined) throw new Error(`Flag --${key} takes no value`); parsed[key] = "true"; }
    else { const value = inline ?? args[++i]; if (!value || value.startsWith("--")) throw new Error(`Missing --${key} value`); parsed[key] = value; }
  }
  if (parsed.source && !["osm", "overture"].includes(parsed.source)) throw new Error("source must be overture or osm");
  if (parsed.city && !["cairo", "giza"].includes(parsed.city)) throw new Error("city must be cairo or giza");
  const source = (parsed.source ?? "overture") as "osm" | "overture";
  console.log(
    JSON.stringify(
      parsed.status
        ? await syncStatus(source)
        : await synchronizePlaces({
            source, city: parsed.city as "cairo" | "giza" | undefined,
            dryRun: !!parsed["dry-run"], reuse: !!parsed.reuse,
            limit: parsed.limit === undefined ? undefined : Number(parsed.limit),
            batchSize: parsed["batch-size"] === undefined ? undefined : Number(parsed["batch-size"]),
            manifest: parsed.manifest, resume: parsed.resume, signal: stop.signal,
          }),
      null,
      2,
    ),
  );
} catch (error) {
  console.error(error instanceof Error ? error.message : "Sync failed");
  process.exitCode = 1;
} finally {
  await prisma.$disconnect();
}
