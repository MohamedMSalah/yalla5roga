import 'package:latlong2/latlong.dart';
import 'package:yalla_5roga/features/starting_location/domain/entities/effective_starting_location.dart';
import 'package:yalla_5roga/features/transportation/domain/entities/routing_capabilities.dart';
import 'package:yalla_5roga/features/transportation/domain/entities/transportation_preference.dart';

typedef RoutePreviewTarget = ({
  StartingLocationScope scope,
  ({String placeId, String calculationId, int inputVersion})? recommendation,
});

typedef RoutePreviewPoint = ({LatLng point, String? name, String? arabicName});

enum RoutePreviewStatus {
  available,
  unavailable,
  unsupportedMode,
  startingLocationRequired,
  transportationRequired,
  noRoute,
  invalidRoute,
}

enum RouteEstimateQuality { estimated, trafficAware }

class RoutePreviewAlternative {
  const RoutePreviewAlternative({
    required this.points,
    required this.distanceMeters,
    required this.durationSeconds,
  });

  final List<LatLng> points;
  final double distanceMeters, durationSeconds;
}

class RoutePreviewEntity {
  const RoutePreviewEntity({
    required this.status,
    required this.inputVersion,
    required this.expiresAt,
    required this.startingLocationStatus,
    required this.origin,
    required this.destination,
    required this.mode,
    required this.capabilities,
    this.calculatedAt,
    this.quality,
    this.routes = const [],
  });

  final RoutePreviewStatus status;
  final int inputVersion;
  final DateTime expiresAt;
  final EffectiveLocationStatus startingLocationStatus;
  final RoutePreviewPoint? origin;
  final RoutePreviewPoint destination;
  final TransportationMode? mode;
  final RoutingCapabilities? capabilities;
  final DateTime? calculatedAt;
  final RouteEstimateQuality? quality;
  final List<RoutePreviewAlternative> routes;
}
