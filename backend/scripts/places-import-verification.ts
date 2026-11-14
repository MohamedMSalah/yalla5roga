import "dotenv/config";
import { createHash } from "node:crypto";
import { writeFileSync } from "node:fs";
import { prisma } from "../src/config/database.js";
import {
  synchronizePlaces,
  syncStatus,
} from "../src/services/places/places-sync.js";
const full = process.argv.includes("--full");
const fingerprint = (v: unknown) =>
  createHash("sha256").update(JSON.stringify(v)).digest("hex");
async function preserved() {
  return {
    outings: await prisma.outings.findMany({ orderBy: { id: "asc" } }),
    manual: await prisma.places.findMany({
      where: { source: "manual" },
      orderBy: { id: "asc" },
    }),
  };
}
let report: Record<string, unknown> = {
  checkedAt: new Date().toISOString(),
  mode: full ? "full" : "initial",
  limit: full ? null : Number(process.env.PLACES_INITIAL_IMPORT_LIMIT ?? 1000),
};
try {
  const before = await preserved();
  const run = await synchronizePlaces(
    full ? {} : { limit: Number(report.limit) },
  );
  const after = await preserved();
  report = {
    ...report,
    run,
    manual_places_preserved:
      fingerprint(before.manual) === fingerprint(after.manual),
    existing_outings_preserved:
      fingerprint(before.outings) === fingerprint(after.outings),
    counts: await prisma.places.groupBy({
      by: ["source", "source_region", "status"],
      _count: true,
    }),
    status: await syncStatus(),
    result: "PASS",
  };
  if (!report.manual_places_preserved || !report.existing_outings_preserved)
    throw new Error("Existing values changed; inspect concurrent writes");
  console.log(JSON.stringify(report, null, 2));
} catch (error) {
  report = {
    ...report,
    result: "FAILED",
    reason: error instanceof Error ? error.message : "Unknown",
  };
  process.exitCode = 1;
  console.error(report.reason);
} finally {
  writeFileSync(
    `../docs/audit/PLACES_${full ? "FULL" : "INITIAL"}_IMPORT.json`,
    JSON.stringify(report, null, 2) + "\n",
  );
  await prisma.$disconnect();
}
