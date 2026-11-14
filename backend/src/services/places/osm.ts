import { categories, classify, mappedVibes, type Tags } from "./taxonomy.js";

export const OSM_ATTRIBUTION = "© OpenStreetMap contributors — ODbL 1.0";
export const REGIONS = ["EG-C", "EG-GZ"] as const;
export const TAG_KEYS = [
  "amenity",
  "shop",
  "leisure",
  "tourism",
  "historic",
  "sport",
] as const;
export type OsmElement = {
  type: string;
  id: number;
  lat?: number;
  lon?: number;
  center?: { lat: number; lon: number };
  tags?: Tags;
  version?: number;
  timestamp?: string;
};
export type NormalizedPlace = NonNullable<ReturnType<typeof normalizeOsm>>;

export function lifecycle(tags: Tags): { status: string; evidence: Tags } {
  const evidence = Object.fromEntries(
    Object.entries(tags).filter(([k]) =>
      /^(disused|abandoned|demolished|removed|razed|was|closed|temporary|opening_hours|end_date)/.test(
        k,
      ),
    ),
  );
  // Retired feature tags establish the identity's closure, unlike a missing query row.
  if (
    Object.keys(tags).some((k) =>
      /^(abandoned|demolished|removed|razed|was):/.test(k),
    ) ||
    ["abandoned", "demolished", "removed", "razed"].some(
      (k) => tags[k] === "yes",
    )
  ) {
    return { status: "permanently_closed", evidence };
  }
  if (
    tags.disused === "yes" ||
    Object.keys(tags).some((k) => /^(disused|closed):/.test(k)) ||
    tags.temporary === "closed" ||
    /^(closed|off)$/i.test(tags.opening_hours ?? "")
  ) {
    return { status: "temporarily_closed", evidence };
  }
  return { status: "active", evidence };
}

function text(value: string | undefined, max: number): string | null {
  return (
    value
      ?.normalize("NFC")
      .replace(/[\u0000-\u001f\u007f]/g, " ")
      .replace(/\s+/g, " ")
      .trim()
      .slice(0, max) || null
  );
}
function web(value: string | undefined): string | null {
  if (!value) return null;
  try {
    const url = new URL(value.includes("://") ? value : `https://${value}`);
    return ["http:", "https:"].includes(url.protocol)
      ? url.toString().slice(0, 2048)
      : null;
  } catch {
    return null;
  }
}
export function normalizeOsm(element: OsmElement, region: string) {
  if (
    !["node", "way", "relation"].includes(element.type) ||
    !Number.isSafeInteger(element.id) ||
    element.id <= 0
  )
    return null;
  const tags = element.tags ?? {};
  const lat = element.lat ?? element.center?.lat,
    lng = element.lon ?? element.center?.lon;
  const name = text(tags.name ?? tags["name:ar"] ?? tags["name:en"], 100);
  if (
    !name ||
    lat == null ||
    lng == null ||
    !Number.isFinite(lat) ||
    !Number.isFinite(lng) ||
    Math.abs(lat) > 90 ||
    Math.abs(lng) > 180
  )
    return null;
  const classificationTags = { ...tags };
  for (const [key, value] of Object.entries(tags)) {
    const match =
      /^(?:disused|abandoned|demolished|removed|razed|was|closed):(.+)$/.exec(
        key,
      );
    if (match && !classificationTags[match[1]!])
      classificationTags[match[1]!] = value;
  }
  const category = classify(classificationTags);
  if (!category) return null;
  const state = lifecycle(tags);
  // A prefix alone does not establish reopening. A current supported category is required.
  if (state.status === "active" && !classify(tags)) state.status = "unverified";
  return {
    name,
    name_ar: text(tags["name:ar"], 100),
    name_en: text(tags["name:en"], 100),
    description:
      text(
        tags.description ?? tags["description:en"] ?? tags["description:ar"],
        1000,
      ) ?? "",
    category_id: category,
    latitude: lat,
    longitude: lng,
    address:
      text(tags["addr:full"], 1000) ??
      text(
        [
          tags["addr:housenumber"],
          tags["addr:street"],
          tags["addr:suburb"],
          tags["addr:city"],
        ]
          .filter(Boolean)
          .join(", "),
        1000,
      ),
    city: text(tags["addr:city"], 100),
    district: text(tags["addr:district"] ?? tags["addr:suburb"], 100),
    area:
      text(
        tags["addr:district"] ?? tags["addr:suburb"] ?? tags["addr:city"],
        100,
      ) ?? "",
    phone: text(tags["contact:phone"] ?? tags.phone, 100),
    website: web(tags["contact:website"] ?? tags.website),
    opening_hours: text(tags.opening_hours, 1000),
    source: "osm",
    source_type: element.type,
    source_id: String(element.id),
    source_region: region,
    source_tags: {
      tags,
      meta: {
        version: element.version ?? null,
        edited_at: element.timestamp ?? null,
      },
    },
    status: state.status,
    vibe: categories.find((c) => c[0] === category)![5],
    vibes: mappedVibes(category, tags),
    evidence: {
      ...state.evidence,
      osm_version: element.version ?? 0,
      osm_timestamp: element.timestamp ?? "",
      identity: `${element.type}/${element.id}`,
    },
  };
}

export function overpassQuery(region: string, key: string): string {
  if (
    !(REGIONS as readonly string[]).includes(region) ||
    !(TAG_KEYS as readonly string[]).includes(key)
  )
    throw new Error("Invalid OSM coverage");
  // Area IDs are resolved from administrative boundaries, never district names/bboxes.
  const values: Record<string, string> = {
    amenity:
      "restaurant|fast_food|cafe|ice_cream|cinema|marketplace|arts_centre|social_centre|community_centre|lounge",
    shop: "coffee|bakery|pastry|confectionery|ice_cream|mall|department_store",
    leisure:
      "bowling_alley|escape_game|virtual_reality|trampoline_park|amusement_arcade|gaming_centre|gaming_center|ice_rink|sports_centre|fitness_centre|indoor_play|adventure_park|park|garden|social_club",
    tourism: "zoo|picnic_site|theme_park|museum|gallery|viewpoint|attraction",
    historic: "castle|archaeological_site|monument|memorial|ruins|fort",
    sport: "karting|bowling|billiards",
  };
  // Exact indexed keys avoid a global regular-expression scan over every OSM tag.
  const selectors = [
    "",
    "disused:",
    "abandoned:",
    "demolished:",
    "removed:",
    "razed:",
    "was:",
    "closed:",
  ]
    .map((prefix) => `nwr(area.a)["${prefix}${key}"~"^(${values[key]})$"];`)
    .join("");
  return `[out:json][timeout:120];area["ISO3166-2"="${region}"]["boundary"="administrative"]->.a;.a out count;(${selectors})->.p;.p out meta center;.p out count;`;
}

export function validateResponse(body: any): OsmElement[] {
  if (
    body?.remark ||
    !Array.isArray(body?.elements) ||
    !body?.osm3s?.timestamp_osm_base
  )
    throw new Error("Incomplete Overpass response");
  const counts = body.elements.filter((e: any) => e.type === "count");
  const elements = body.elements.filter((e: any) => e.type !== "count");
  if (
    counts.length !== 2 ||
    Number(counts[0]?.tags?.areas) !== 1 ||
    Number(counts[1]?.tags?.total) !== elements.length
  )
    throw new Error("OSM boundary/count validation failed");
  const age = Date.now() - Date.parse(body.osm3s.timestamp_osm_base);
  if (!Number.isFinite(age) || age > 48 * 3600_000 || age < -3600_000)
    throw new Error(
      `Stale OSM snapshot: ${body.osm3s.timestamp_osm_base} (observed ${new Date().toISOString()})`,
    );
  return Object.assign(elements, {
    sourceTimestamp: body.osm3s.timestamp_osm_base as string,
  });
}

let nextRequestAt = 0;
export async function fetchOverpass(query: string): Promise<OsmElement[]> {
  const endpoints = (
    process.env.OSM_OVERPASS_URLS ??
    process.env.OSM_OVERPASS_URL ??
    "https://overpass-api.de/api/interpreter,https://overpass.private.coffee/api/interpreter"
  )
    .split(",")
    .map((v) => v.trim())
    .filter(Boolean);
  if (
    !endpoints.length ||
    endpoints.some((endpoint) => new URL(endpoint).protocol !== "https:")
  )
    throw new Error("OSM endpoints must use HTTPS");
  for (let attempt = 0; attempt < 4; attempt++) {
    const endpoint = endpoints[attempt % endpoints.length]!;
    await new Promise((resolve) =>
      setTimeout(resolve, Math.max(0, nextRequestAt - Date.now())),
    );
    nextRequestAt =
      Date.now() +
      Math.max(2000, Number(process.env.OSM_REQUEST_INTERVAL_MS) || 3000);
    try {
      if (process.env.PLACES_SYNC_QUIET !== "1")
        console.log(
          JSON.stringify({
            osm_request_host: new URL(endpoint).hostname,
            attempt: attempt + 1,
          }),
        );
      const response = await fetch(endpoint, {
        method: "POST",
        headers: {
          "Content-Type": "application/x-www-form-urlencoded",
          "User-Agent": process.env.OSM_USER_AGENT ?? "Yalla5roga-Places/1.0",
        },
        body: new URLSearchParams({ data: query }),
        signal: AbortSignal.timeout(150_000),
      });
      if (!response.ok) {
        const retryHeader = response.headers.get("retry-after");
        const seconds = Number(retryHeader);
        const delay = Number.isFinite(seconds)
          ? seconds * 1000
          : Date.parse(retryHeader ?? "") - Date.now();
        if (delay > 0)
          nextRequestAt = Math.max(nextRequestAt, Date.now() + delay);
        throw new Error(`Overpass HTTP ${response.status}`);
      }
      return validateResponse(await response.json());
    } catch (error) {
      if (process.env.PLACES_SYNC_QUIET !== "1")
        console.warn(
          JSON.stringify({
            osm_request_failed: attempt + 1,
            reason:
              error instanceof Error ? error.message : "Unknown source error",
          }),
        );
      if (attempt === 3) throw error;
      nextRequestAt = Math.max(
        nextRequestAt,
        Date.now() + 2000 * 2 ** attempt + Math.random() * 1000,
      );
    }
  }
  throw new Error("Overpass retries exhausted");
}
