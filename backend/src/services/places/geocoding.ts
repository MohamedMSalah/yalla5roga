import { z } from "zod";

const language = z.enum(["en", "ar"]);
export const geocodingRequest = z.discriminatedUnion("kind", [
  z.object({ kind: z.literal("search"), query: z.string().trim().min(2).max(120), language }),
  z.object({
    kind: z.literal("reverse"),
    latitude: z.number().min(-90).max(90),
    longitude: z.number().min(-180).max(180),
    language,
  }),
]);

export type GeocodingRequest = z.infer<typeof geocodingRequest>;
export type GeocodingHit = {
  id: string;
  name: string;
  area: string;
  latitude: number;
  longitude: number;
};

export interface GeocodingProvider {
  attribution: string;
  cacheSeconds: number;
  lookup(request: GeocodingRequest, signal: AbortSignal): Promise<GeocodingHit[]>;
}

const feature = z.object({
  geometry: z.object({
    type: z.literal("Point"),
    coordinates: z.tuple([z.number().min(-180).max(180), z.number().min(-90).max(90)]),
  }),
  properties: z.object({
    gid: z.string(),
    name: z.string().trim().min(1),
    locality: z.string().nullish(),
    region: z.string().nullish(),
    country: z.string().nullish(),
  }),
});

export function configuredGeocodingProvider(env = process.env): GeocodingProvider | undefined {
  if (env.GEOCODING_PROVIDER !== "pelias") return undefined;
  const attribution = env.GEOCODING_ATTRIBUTION?.trim();
  let base: URL;
  try {
    base = new URL(env.GEOCODING_BASE_URL ?? "");
  } catch {
    return undefined;
  }
  if (base.protocol !== "https:" || base.username || base.password ||
      base.search || base.hash || !attribution ||
      base.hostname === "nominatim.openstreetmap.org") return undefined;
  const configuredCache = Number(env.GEOCODING_CACHE_SECONDS);
  const cacheSeconds = Number.isSafeInteger(configuredCache)
    ? Math.min(300, Math.max(0, configuredCache))
    : 0;

  return {
    attribution,
    cacheSeconds,
    async lookup(request, signal) {
      const path = request.kind === "search" ? "autocomplete" : "reverse";
      const url = new URL(`${base.href.replace(/\/$/, "")}/v1/${path}`);
      url.searchParams.set("lang", request.language);
      url.searchParams.set("size", request.kind === "search" ? "6" : "1");
      if (request.kind === "search") {
        url.searchParams.set("text", request.query);
      } else {
        url.searchParams.set("point.lat", String(request.latitude));
        url.searchParams.set("point.lon", String(request.longitude));
      }
      if (env.GEOCODING_API_KEY) url.searchParams.set("api_key", env.GEOCODING_API_KEY);
      const response = await fetch(url, { signal, redirect: "error" });
      if (!response.ok) throw new Error("Geocoding upstream request failed");
      const payload = z.object({ features: z.array(z.unknown()) }).parse(await response.json());
      return payload.features.slice(0, request.kind === "search" ? 6 : 1).flatMap((item) => {
        const parsed = feature.safeParse(item);
        if (!parsed.success) return [];
        const { geometry: { coordinates: [longitude, latitude] }, properties } = parsed.data;
        return [{
          id: properties.gid,
          name: properties.name,
          area: properties.locality ?? properties.region ?? properties.country ?? "",
          latitude,
          longitude,
        }];
      });
    },
  };
}
