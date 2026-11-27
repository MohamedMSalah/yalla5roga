import 'package:dio/dio.dart';
import 'package:latlong2/latlong.dart';
import 'package:yalla_5roga/core/constants/api_constants.dart';
import 'package:yalla_5roga/core/network/api_client.dart';
import 'package:yalla_5roga/core/network/dio_interceptors.dart';
import 'package:yalla_5roga/features/transportation/domain/entities/transportation_preference.dart';

import '../../domain/entities/effective_starting_location.dart';

class StartingLocationRemoteDataSource {
  const StartingLocationRemoteDataSource(this._api);

  final ApiClient _api;

  String _path(StartingLocationScope scope) => switch (scope.context) {
    StartingLocationContext.meetup => ApiConstants.meetupStartingLocation(
      scope.id,
    ),
    StartingLocationContext.outing => ApiConstants.outingStartingLocation(
      scope.id,
    ),
  };

  Options _bound(String account) =>
      Options(extra: {expectedUserIdKey: account});

  Future<EffectiveStartingLocation> get(
    String account,
    StartingLocationScope scope,
  ) => _decode(
    _api.get<Map<String, dynamic>>(_path(scope), options: _bound(account)),
  );

  Future<EffectiveStartingLocation> clear(
    String account,
    StartingLocationScope scope,
  ) => _decode(
    _api.delete<Map<String, dynamic>>(_path(scope), options: _bound(account)),
  );

  Future<EffectiveStartingLocation> set(
    String account,
    StartingLocationScope scope,
    StartingLocationOverride override,
    String? consentPolicyVersion,
  ) => _decode(
    _api.put<Map<String, dynamic>>(
      _path(scope),
      options: _bound(account),
      data: <String, Object?>{
        'location_source': override.source.code,
        if (override.transportation case final mode?)
          'transportation_mode': mode.code,
        'consent_policy_version': ?consentPolicyVersion,
        if (override.source == OverrideLocationSource.personal)
          'personal_location_id': override.referenceId,
        if (override.source == OverrideLocationSource.savedPlace)
          'saved_place_id': override.referenceId,
        if (override.point case final point?) ...{
          'latitude': point.latitude,
          'longitude': point.longitude,
        },
      },
    ),
  );

  static LatLng? _point(Map<String, dynamic>? row) {
    final latitude = row?['latitude'] as num?;
    final longitude = row?['longitude'] as num?;
    return latitude == null || longitude == null
        ? null
        : LatLng(latitude.toDouble(), longitude.toDouble());
  }

  static TransportationMode? _mode(Object? code) =>
      TransportationMode.values.where((mode) => mode.code == code).firstOrNull;

  Future<EffectiveStartingLocation> _decode(
    Future<Response<Map<String, dynamic>>> request,
  ) async {
    final body = (await request).data;
    if (body?['success'] != true) {
      throw const FormatException('Invalid starting location response');
    }
    final data = body!['data'] as Map<String, dynamic>;
    final location = data['location'] as Map<String, dynamic>?;
    final override = data['override'] as Map<String, dynamic>?;
    final transportation = data['transportation'] as Map<String, dynamic>;
    return EffectiveStartingLocation(
      status: EffectiveLocationStatus.values.firstWhere(
        (status) => status.code == data['status'],
      ),
      consentPolicyVersion: data['consent_policy_version'] as String,
      inputVersion: data['input_version'] as int,
      point: _point(location),
      name: location?['name'] as String?,
      arabicName: location?['name_ar'] as String?,
      temporaryLocation: location?['temporary'] == true,
      transportation: _mode(transportation['mode']),
      temporaryTransportation: transportation['source'] == 'temporary_override',
      expiresAt: override == null
          ? null
          : DateTime.parse(override['expires_at'] as String),
      override: override == null
          ? null
          : StartingLocationOverride(
              source: OverrideLocationSource.values.firstWhere(
                (source) => source.code == override['location_source'],
              ),
              referenceId:
                  (override['personal_location_id'] ??
                          override['saved_place_id'])
                      as String?,
              point: _point(override),
              transportation: _mode(override['transportation_mode']),
            ),
    );
  }
}
