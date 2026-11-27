import {
  routeOutcomeSchema, type RoutePoint, type RouteRequest, type RouteResult, type RoutingFailure,
} from "../../types/routing/route-preview.js";
import { routingCapabilities, routingUnavailableReason, type TransportationMode } from "../../types/users/transportation.types.js";

export interface RoutePreviewService {
  readonly available: boolean;
  capabilities(mode: TransportationMode): typeof routingCapabilities[number] | null;
  preview(request: RouteRequest): Promise<RouteResult | RoutingFailure>;
}

export class UnavailableRoutePreviewService implements RoutePreviewService {
  readonly available = false;
  capabilities(mode: TransportationMode) {
    return routingCapabilities.find(row => row.mode === mode) ?? null;
  }

  async preview(request: RouteRequest): Promise<RoutingFailure> {
    return { status: "ROUTING_UNAVAILABLE", capabilities: this.capabilities(request.mode) };
  }
}

type Inputs = Omit<RouteRequest, "origin" | "destination" | "mode"> & {
  origin: RoutePoint | null;
  destination: RoutePoint;
  mode: TransportationMode | null;
};

export async function resolveRoutePreview(service: RoutePreviewService, { origin, destination, mode, ...context }: Inputs):
    Promise<RouteResult | RoutingFailure> {
  const capabilities = mode ? service.capabilities(mode) : null;
  if (!service.available) return { status: "ROUTING_UNAVAILABLE", capabilities };
  if (!mode) return { status: "TRANSPORTATION_MODE_REQUIRED", capabilities };
  if (!capabilities || !capabilities.supports_routes) {
    return {
      status: capabilities?.unavailability_reason_code === routingUnavailableReason
        ? "ROUTING_UNAVAILABLE" : "MODE_UNSUPPORTED",
      capabilities,
    };
  }
  if (!origin) return { status: "STARTING_LOCATION_REQUIRED", capabilities };
  const outcome = routeOutcomeSchema.safeParse(await service.preview({ ...context, origin, destination, mode }));
  if (!outcome.success) return { status: "INVALID_ROUTE", capabilities };
  if (outcome.data.status !== "AVAILABLE") return outcome.data;
  if (outcome.data.mode !== mode || !capabilities.supports_distance || !capabilities.supports_duration) {
    return { status: "INVALID_ROUTE", capabilities };
  }
  const { alternatives, ...route } = outcome.data;
  return {
    ...route,
    capabilities,
    ...(capabilities.supports_alternatives && alternatives?.length ? { alternatives } : {}),
  };
}
