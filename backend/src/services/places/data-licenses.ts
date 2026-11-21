import { readFileSync } from "node:fs";
import { markCache } from "../../monitoring/context.js";
const root = new URL("../../../licenses/", import.meta.url);
const loadCatalogLicenses = () => ({
  attribution: "Overture Maps Foundation; © OpenStreetMap contributors",
  license_policy: "Source evidence stays separate. OSM-derived catalog data is available under ODbL 1.0; permissive upstream notices remain applicable. Private application/user data is excluded.",
  licenses: [
    { id: "CDLA-Permissive-2.0", url: "https://cdla.dev/permissive-2-0/", text: readFileSync(new URL("CDLA-Permissive-2.0.txt", root), "utf8") },
    { id: "ODbL-1.0", url: "https://opendatacommons.org/licenses/odbl/1-0/", text: readFileSync(new URL("ODbL-1.0.html", root), "utf8") },
    { id: "Apache-2.0", url: "https://www.apache.org/licenses/LICENSE-2.0", text: readFileSync(new URL("Apache-2.0.txt", root), "utf8") },
    { id: "CC0-1.0", url: "https://creativecommons.org/publicdomain/zero/1.0/" },
  ],
  sources: [
    { name: "Overture Maps Foundation", attribution_url: "https://docs.overturemaps.org/attribution/" },
    { name: "OpenStreetMap contributors", attribution_url: "https://www.openstreetmap.org/copyright" },
    { name: "Geofabrik", attribution_url: "https://download.geofabrik.de/africa/egypt.html" },
    { name: "Foursquare", copyright: "© 2026 Foursquare Labs, Inc. All rights reserved.", modifications: "Transformed to the Overture schema and normalized into the Yalla 5roga catalog.", notice_url: "https://opensource.foursquare.com/places-notice-txt/", notice: readFileSync(new URL("Foursquare-NOTICE.html", root), "utf8") },
  ],
});

let cached: ReturnType<typeof loadCatalogLicenses> | undefined;
export function catalogLicenses() {
  if (cached) {
    markCache("hit");
    return cached;
  }
  markCache("miss");
  cached = loadCatalogLicenses();
  return cached;
}
