/** Remove only import-derived city fallbacks: administrative region != verified venue city. */
import { mkdirSync, writeFileSync } from "node:fs";
import { prisma } from "../src/config/database.js";
import { verifyPlacesTarget } from "../src/services/places/places-sync.js";
import { notifyCatalogChanged } from "../src/services/places/catalog-notifications.js";
import { cleanText } from "../src/services/places/import-normalization.js";
try {
  const target = await verifyPlacesTarget();
  const candidates = await prisma.$queryRaw<any[]>`SELECT p.id,p.source,p.city,s.evidence FROM places p JOIN place_source_records s
    ON s.place_id=p.id AND s.source=p.source AND s.source_type=p.source_type AND s.source_id=p.source_id
    WHERE NOT p.manually_managed AND p.city IN ('Cairo','Giza')`;
  const rows = candidates.filter((p) => {
    if (p.source === "osm") return !cleanText(p.evidence.tags?.["addr:city"], 100);
    if (p.source !== "overture") return false;
    const address = p.evidence.addresses?.find((a: any) => a.country === "EG") ?? p.evidence.addresses?.[0];
    return !cleanText(address?.locality, 100);
  }).map(({ evidence, ...row }) => row);
  if (process.argv.includes("--apply") && rows.length) {
    mkdirSync(".database-backups", { recursive: true });
    writeFileSync(`.database-backups/places-derived-city-${Date.now()}.json`, JSON.stringify({ target, rows }, null, 2));
    await prisma.$transaction(async (tx) => {
      await tx.places.updateMany({ where: { id: { in: rows.map((r) => r.id) }, manually_managed: false, city: { in: ["Cairo", "Giza"] } }, data: { city: null } });
      await notifyCatalogChanged(tx);
    });
  }
  console.log(JSON.stringify({ target, mode: process.argv.includes("--apply") ? "applied" : "read-only", derived_city_values: rows.length }));
} finally { await prisma.$disconnect(); }
