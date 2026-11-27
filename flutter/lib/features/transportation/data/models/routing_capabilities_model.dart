import '../../domain/entities/routing_capabilities.dart';
import 'transportation_preference_model.dart';

abstract final class RoutingCapabilitiesModel {
  static RoutingCapabilities? fromJson(Map<String, dynamic> json) {
    final mode = TransportationPreferenceModel.modeFromJson(json['mode']);
    if (mode == null) return null;
    return RoutingCapabilities(
      mode: mode,
      canStorePreference: json['can_store_preference'] as bool,
      supportsRoutes: json['supports_routes'] as bool,
      supportsMatrices: json['supports_matrices'] as bool,
      supportsDistance: json['supports_distance'] as bool,
      supportsDuration: json['supports_duration'] as bool,
      supportsAlternatives: json['supports_alternatives'] as bool,
      supportsIsochrones: json['supports_isochrones'] as bool,
      supportsDepartureTime: json['supports_departure_time'] as bool,
      unavailabilityReasonCode: json['unavailability_reason_code'] as String?,
    );
  }
}
