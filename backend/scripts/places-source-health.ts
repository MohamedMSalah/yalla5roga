/** Small read-only source freshness check; never imports or changes the DB. */
import { writeFileSync, readFileSync, existsSync } from "node:fs";
const file = "../docs/audit/PLACES_SOURCE_HEALTH.json";
const results: any[] = existsSync(file)
  ? JSON.parse(readFileSync(file, "utf8"))
  : [];
for (const endpoint of (
  process.env.OSM_HEALTH_ENDPOINTS?.trim() ||
  "https://overpass-api.de/api/interpreter,https://overpass.private.coffee/api/interpreter,https://overpass.kumi.systems/api/interpreter"
).split(",")) {
  const url = new URL(endpoint);
  url.searchParams.set("data", "[out:json][timeout:10];node(1);out;");
  try {
    const response = await fetch(url, {
      headers: { "User-Agent": "Yalla5roga-Places/1.0" },
      signal: AbortSignal.timeout(20000),
    });
    const raw = await response.text();
    let body: any;
    try {
      body = JSON.parse(raw);
    } catch {}
    const result = {
      endpoint,
      status: response.status,
      snapshot: body?.osm3s?.timestamp_osm_base,
      remark: body?.remark,
      observedAt: new Date().toISOString(),
    };
    results.push(result);
    console.log(JSON.stringify(result));
  } catch (error) {
    const result = {
      endpoint,
      error: error instanceof Error ? error.message : "Unknown",
      observedAt: new Date().toISOString(),
    };
    results.push(result);
    console.log(JSON.stringify(result));
  }
}
writeFileSync(file, JSON.stringify(results, null, 2) + "\n");
