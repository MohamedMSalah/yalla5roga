export const transportationModes = ["CAR", "MOTORCYCLE", "METRO", "WALKING"] as const;
export type TransportationMode = typeof transportationModes[number];

export type TransportationPreferences = {
  default_transportation_mode: TransportationMode | null;
};

export type SavedTransportationPreference = {
  preferred_transportation_mode: TransportationMode | null;
};

export interface RoutingCapabilities {
  mode: TransportationMode;
  can_store_preference: boolean;
  supports_routes: boolean;
  supports_matrices: boolean;
  supports_distance: boolean;
  supports_duration: boolean;
  supports_alternatives: boolean;
  supports_isochrones: boolean;
  supports_departure_time: boolean;
  unavailability_reason_code: string | null;
}

export const routingUnavailableReason = "ROUTING_NOT_CONFIGURED";

export const routingCapabilities: readonly RoutingCapabilities[] = transportationModes.map((mode) => ({
  mode,
  can_store_preference: true,
  supports_routes: false,
  supports_matrices: false,
  supports_distance: false,
  supports_duration: false,
  supports_alternatives: false,
  supports_isochrones: false,
  supports_departure_time: false,
  unavailability_reason_code: routingUnavailableReason,
}));
