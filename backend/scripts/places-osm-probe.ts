import "dotenv/config";
import { writeFileSync } from "node:fs";
import {
  overpassQuery,
  fetchOverpass,
  normalizeOsm,
} from "../src/services/places/osm.js";
const query = overpassQuery("EG-C", "amenity");
try {
  const rows = await fetchOverpass(query);
  const places = rows.map((r) => normalizeOsm(r, "EG-C")).filter(Boolean);
  const metadata = {
    checkedAt: new Date().toISOString(),
    status: "PASS",
    elements: rows.length,
    validPlaces: places.length,
  };
  console.log(JSON.stringify(metadata));
  writeFileSync(
    "../docs/audit/PLACES_OSM_PROBE.json",
    JSON.stringify(metadata, null, 2) + "\n",
  );
} catch (error) {
  writeFileSync(
    "../docs/audit/PLACES_OSM_PROBE.json",
    JSON.stringify(
      {
        checkedAt: new Date().toISOString(),
        status: "FAILED",
        reason: error instanceof Error ? error.message : "Unknown",
      },
      null,
      2,
    ) + "\n",
  );
  throw error;
}
