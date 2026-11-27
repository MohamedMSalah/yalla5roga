import 'transportation_preference.dart';

class RoutingCapabilities {
  const RoutingCapabilities({
    required this.mode,
    required this.canStorePreference,
    required this.supportsRoutes,
    required this.supportsMatrices,
    required this.supportsDistance,
    required this.supportsDuration,
    required this.supportsAlternatives,
    required this.supportsIsochrones,
    required this.supportsDepartureTime,
    required this.unavailabilityReasonCode,
  });

  final TransportationMode mode;
  final bool canStorePreference;
  final bool supportsRoutes;
  final bool supportsMatrices;
  final bool supportsDistance;
  final bool supportsDuration;
  final bool supportsAlternatives;
  final bool supportsIsochrones;
  final bool supportsDepartureTime;
  final String? unavailabilityReasonCode;
}
