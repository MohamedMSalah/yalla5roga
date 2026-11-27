import { z } from "zod";
import type { RoutingCapabilities, TransportationMode } from "../users/transportation.types.js";
import { transportationModes } from "../users/transportation.types.js";
import type { StartingLocationContext } from "../users/starting-location-override.js";

export type { RoutingCapabilities } from "../users/transportation.types.js";

const positionSchema = z.tuple([z.number().min(-180).max(180), z.number().min(-90).max(90)]);

export const routeGeometrySchema = z.object({
  type: z.literal("LineString"),
  coordinates: z.array(positionSchema).min(2).refine(points =>
    points.some(([lon, lat]) => lon !== points[0][0] || lat !== points[0][1])),
});

export type RouteGeometry = z.infer<typeof routeGeometrySchema>;

const routePointSchema = z.object({
  latitude: z.number().min(-90).max(90),
  longitude: z.number().min(-180).max(180),
  name: z.string().nullable(),
  name_ar: z.string().nullable(),
});

export type RoutePoint = z.infer<typeof routePointSchema>;
export const isRoutePoint = (value: unknown): value is RoutePoint => routePointSchema.safeParse(value).success;

export interface RouteRequest {
  context: StartingLocationContext;
  input_version: number;
  origin: RoutePoint;
  destination: RoutePoint;
  mode: TransportationMode;
}

export const routeAlternativeSchema = z.object({
  distance_meters: z.number().nonnegative(),
  duration_seconds: z.number().nonnegative(),
  geometry: routeGeometrySchema,
});

export type RouteAlternative = z.infer<typeof routeAlternativeSchema>;

const capabilities = z.object({
  mode: z.enum(transportationModes),
  can_store_preference: z.boolean(),
  supports_routes: z.boolean(),
  supports_matrices: z.boolean(),
  supports_distance: z.boolean(),
  supports_duration: z.boolean(),
  supports_alternatives: z.boolean(),
  supports_isochrones: z.boolean(),
  supports_departure_time: z.boolean(),
  unavailability_reason_code: z.string().nullable(),
}) satisfies z.ZodType<RoutingCapabilities>;

const result = routeAlternativeSchema.extend({
  status: z.literal("AVAILABLE"),
  mode: z.enum(transportationModes),
  calculated_at: z.iso.datetime(),
  estimate_quality: z.enum(["ESTIMATED", "TRAFFIC_AWARE"]),
  capabilities,
  alternatives: z.array(routeAlternativeSchema).optional(),
});

const failure = z.object({
  status: z.enum(["ROUTING_UNAVAILABLE", "MODE_UNSUPPORTED", "STARTING_LOCATION_REQUIRED",
    "TRANSPORTATION_MODE_REQUIRED", "NO_ROUTE", "INVALID_ROUTE"]),
  capabilities: capabilities.nullable(),
});

export const routeOutcomeSchema = z.discriminatedUnion("status", [result, failure]);
export type RouteResult = z.infer<typeof result>;
export type RoutingFailure = z.infer<typeof failure>;

export const routePreviewSchema = z.object({
  input_version: z.number().int().positive(),
  expires_at: z.iso.datetime(),
  starting_location_status: z.enum(["READY", "STARTING_LOCATION_REQUIRED", "CONSENT_REQUIRED", "GROUP_EXCLUDED"]),
  origin: routePointSchema.nullable(),
  destination: routePointSchema,
  mode: z.enum(transportationModes).nullable(),
  routing: routeOutcomeSchema,
});
