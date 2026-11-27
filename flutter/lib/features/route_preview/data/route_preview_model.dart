import 'package:latlong2/latlong.dart';
import 'package:yalla_5roga/core/maps/route_geometry.dart';
import 'package:yalla_5roga/features/starting_location/domain/entities/effective_starting_location.dart';
import 'package:yalla_5roga/features/transportation/data/models/routing_capabilities_model.dart';
import 'package:yalla_5roga/features/transportation/data/models/transportation_preference_model.dart';

import '../domain/route_preview_entity.dart';

abstract final class RoutePreviewModel {
  static RoutePreviewEntity fromJson(Map<String, dynamic> json) {
    final routing = json['routing'] as Map<String, dynamic>;
    final mode = TransportationPreferenceModel.modeFromJson(json['mode']);
    final rawCapabilities = routing['capabilities'] as Map<String, dynamic>?;
    final capabilities = rawCapabilities == null
        ? null
        : RoutingCapabilitiesModel.fromJson(rawCapabilities);
    final origin = _point(json['origin'] as Map<String, dynamic>?);
    final destination = _point(json['destination'] as Map<String, dynamic>?);
    if (destination == null) {
      throw const FormatException('Invalid route destination');
    }
    var status = switch (routing['status']) {
      'AVAILABLE' => RoutePreviewStatus.available,
      'ROUTING_UNAVAILABLE' => RoutePreviewStatus.unavailable,
      'MODE_UNSUPPORTED' => RoutePreviewStatus.unsupportedMode,
      'STARTING_LOCATION_REQUIRED' =>
        RoutePreviewStatus.startingLocationRequired,
      'TRANSPORTATION_MODE_REQUIRED' =>
        RoutePreviewStatus.transportationRequired,
      'NO_ROUTE' => RoutePreviewStatus.noRoute,
      _ => RoutePreviewStatus.invalidRoute,
    };
    final routes = <RoutePreviewAlternative>[];
    DateTime? calculatedAt;
    RouteEstimateQuality? quality;
    if (status == RoutePreviewStatus.available) {
      final primary = _route(routing);
      calculatedAt = DateTime.tryParse(
        routing['calculated_at']?.toString() ?? '',
      );
      quality = switch (routing['estimate_quality']) {
        'ESTIMATED' => RouteEstimateQuality.estimated,
        'TRAFFIC_AWARE' => RouteEstimateQuality.trafficAware,
        _ => null,
      };
      if (origin == null ||
          primary == null ||
          mode == null ||
          mode.code != routing['mode'] ||
          capabilities?.mode != mode ||
          capabilities?.supportsRoutes != true ||
          capabilities?.supportsDistance != true ||
          capabilities?.supportsDuration != true ||
          calculatedAt == null ||
          quality == null) {
        status = RoutePreviewStatus.invalidRoute;
      } else {
        routes.add(primary);
        final alternatives = routing['alternatives'];
        if (capabilities?.supportsAlternatives == true &&
            alternatives is List) {
          for (final item in alternatives) {
            if (item is! Map<String, dynamic>) continue;
            if (_route(item) case final route?) {
              routes.add(route);
            }
          }
        }
      }
    }
    return RoutePreviewEntity(
      status: status,
      inputVersion: json['input_version'] as int,
      expiresAt: DateTime.parse(json['expires_at'] as String),
      startingLocationStatus: EffectiveLocationStatus.values.firstWhere(
        (status) => status.code == json['starting_location_status'],
      ),
      origin: origin,
      destination: destination,
      mode: mode,
      capabilities: capabilities,
      calculatedAt: calculatedAt,
      quality: quality,
      routes: List.unmodifiable(routes),
    );
  }

  static LatLng? _coordinates(Object? latitude, Object? longitude) {
    if (latitude is! num ||
        longitude is! num ||
        !latitude.isFinite ||
        !longitude.isFinite ||
        latitude.abs() > 90 ||
        longitude.abs() > 180) {
      return null;
    }
    return LatLng(latitude.toDouble(), longitude.toDouble());
  }

  static RoutePreviewPoint? _point(Map<String, dynamic>? json) {
    final point = _coordinates(json?['latitude'], json?['longitude']);
    if (point == null) return null;
    return (
      point: point,
      name: json?['name'] as String?,
      arabicName: json?['name_ar'] as String?,
    );
  }

  static RoutePreviewAlternative? _route(Map<String, dynamic> json) {
    final geometry = json['geometry'];
    final distance = json['distance_meters'];
    final duration = json['duration_seconds'];
    if (geometry is! Map ||
        geometry['type'] != 'LineString' ||
        distance is! num ||
        !distance.isFinite ||
        distance < 0 ||
        duration is! num ||
        !duration.isFinite ||
        duration < 0) {
      return null;
    }
    final coordinates = geometry['coordinates'];
    if (coordinates is! List) return null;
    final points = <LatLng>[];
    for (final position in coordinates) {
      if (position is! List || position.length != 2) return null;
      final point = _coordinates(position[1], position[0]);
      if (point == null) return null;
      points.add(point);
    }
    if (!isRouteMapLine(points)) return null;
    return RoutePreviewAlternative(
      points: List.unmodifiable(points),
      distanceMeters: distance.toDouble(),
      durationSeconds: duration.toDouble(),
    );
  }
}
