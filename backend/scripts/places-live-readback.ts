import { createHash } from "node:crypto";
import { readFileSync, writeFileSync } from "node:fs";
import { prisma } from "../src/config/database.js";
import { syncStatus } from "../src/services/places/places-sync.js";
try {
  const deployment = JSON.parse(
    readFileSync("../docs/audit/PLACES_MIGRATION_DEPLOYMENT.json", "utf8"),
  );
  const backup = JSON.parse(readFileSync(deployment.privateBackup, "utf8"));
  const [current] = await prisma.$queryRaw<
    { rows: unknown[] }[]
  >`SELECT coalesce(jsonb_agg(to_jsonb(o) ORDER BY to_jsonb(o)::text),'[]'::jsonb) AS rows FROM outings o`;
  const hash = (data: unknown) =>
    createHash("sha256").update(JSON.stringify(data)).digest("hex");
  const report = {
    checkedAt: new Date().toISOString(),
    existing_outings_preserved:
      hash(current!.rows) === backup.tables.outings.checksum,
    original_outing_count: backup.tables.outings.rows.length,
    current_outing_count: current!.rows.length,
    categories: await prisma.place_categories.count({
      where: { is_active: true },
    }),
    vibes: await prisma.vibes.count({ where: { is_active: true } }),
    places: await prisma.places.groupBy({
      by: ["source", "status", "source_region"],
      _count: true,
    }),
    sync: await syncStatus(),
    recent_runs: await prisma.place_sync_runs.findMany({
      take: 5,
      orderBy: { started_at: "desc" },
    }),
  };
  writeFileSync(
    "../docs/audit/PLACES_LIVE_READBACK.json",
    JSON.stringify(report, null, 2) + "\n",
  );
  console.log(JSON.stringify(report, null, 2));
} finally {
  await prisma.$disconnect();
}
