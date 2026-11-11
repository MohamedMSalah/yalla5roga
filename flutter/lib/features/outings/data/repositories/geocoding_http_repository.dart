import 'dart:async';

import 'package:dio/dio.dart';
import 'package:yalla_5roga/core/constants/api_constants.dart';
import 'package:yalla_5roga/core/network/api_client.dart';
import 'package:yalla_5roga/core/network/api_payload.dart';
import 'package:yalla_5roga/features/outings/domain/repositories/location_repository.dart';

class GeocodingHttpRepository implements LocationRepository {
  const GeocodingHttpRepository(this._client);

  final ApiClient _client;

  @override
  Future<LocationLookup> reverseGeocode({
    required double latitude,
    required double longitude,
    required String language,
    required Future<void> cancelled,
  }) => _lookup({
    'kind': 'reverse',
    'latitude': latitude,
    'longitude': longitude,
    'language': language,
  }, cancelled);

  @override
  Future<LocationLookup> search(
    String query, {
    required String language,
    required Future<void> cancelled,
  }) => _lookup({
    'kind': 'search',
    'query': query,
    'language': language,
  }, cancelled);

  Future<LocationLookup> _lookup(
    Map<String, Object> request,
    Future<void> cancelled,
  ) async {
    final token = CancelToken();
    unawaited(cancelled.then((_) => token.cancel()));
    final response = await _client.post<Map<String, dynamic>>(
      ApiConstants.placeGeocoding,
      data: request,
      cancelToken: token,
    );
    final data = apiPayload(response.data);
    return LocationLookup(
      available: data['available'] == true,
      attribution: data['attribution'] as String?,
      cacheSeconds: (data['cache_seconds'] as int? ?? 0).clamp(0, 300),
      hits: [
        if (data['results'] case final List<dynamic> results)
          for (final result in results) ?_hit(result),
      ],
    );
  }

  LocationHit? _hit(Object? result) {
    if (result is! Map<String, dynamic>) return null;
    final latitude = (result['latitude'] as num?)?.toDouble();
    final longitude = (result['longitude'] as num?)?.toDouble();
    final name = (result['name'] as String?)?.trim();
    if (latitude == null ||
        longitude == null ||
        name == null ||
        name.isEmpty ||
        !latitude.isFinite ||
        !longitude.isFinite ||
        latitude.abs() > 90 ||
        longitude.abs() > 180) {
      return null;
    }
    return LocationHit(
      id: result['id'] as String? ?? '',
      name: name,
      area: result['area'] as String? ?? '',
      latitude: latitude,
      longitude: longitude,
    );
  }
}
