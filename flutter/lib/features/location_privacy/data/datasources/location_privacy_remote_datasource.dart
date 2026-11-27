import 'package:dio/dio.dart';
import 'package:yalla_5roga/core/constants/api_constants.dart';
import 'package:yalla_5roga/core/network/api_client.dart';
import 'package:yalla_5roga/core/network/dio_interceptors.dart';

import '../../domain/entities/location_privacy_settings.dart';
import '../models/location_privacy_settings_model.dart';

class LocationPrivacyRemoteDataSource {
  const LocationPrivacyRemoteDataSource(this._api);

  final ApiClient _api;

  Options _bound(String owner) => Options(extra: {expectedUserIdKey: owner});

  Object? _payload(Response<Map<String, dynamic>> response) {
    final body = response.data;
    if (body == null || body['success'] != true || !body.containsKey('data')) {
      throw const FormatException('Invalid location privacy response');
    }
    return body['data'];
  }

  LocationPrivacySettings _settings(Response<Map<String, dynamic>> response) =>
      LocationPrivacySettingsModel.fromJson(
        _payload(response) as Map<String, dynamic>,
      );

  Future<LocationPrivacySettings> getSettings(String owner) async => _settings(
    await _api.get<Map<String, dynamic>>(
      ApiConstants.locationPrivacy,
      options: _bound(owner),
      useSnapshots: false,
    ),
  );

  Future<LocationPrivacySettings> updateVisibility(
    String owner,
    LocationVisibility visibility,
  ) async => _settings(
    await _api.patch<Map<String, dynamic>>(
      ApiConstants.locationPrivacy,
      data: LocationPrivacySettingsModel.visibilityPatch(visibility),
      options: _bound(owner),
    ),
  );

  Future<LocationPrivacySettings> grantConsent(
    String owner,
    String version,
  ) async => _settings(
    await _api.put<Map<String, dynamic>>(
      ApiConstants.locationConsent,
      data: {'consent_policy_version': version},
      options: _bound(owner),
    ),
  );

  Future<LocationPrivacySettings> withdrawConsent(String owner) async =>
      _settings(
        await _api.delete<Map<String, dynamic>>(
          ApiConstants.locationConsent,
          options: _bound(owner),
        ),
      );

  Future<Set<String>> getExcludedGroups(String owner) async {
    final response = await _api.get<Map<String, dynamic>>(
      ApiConstants.locationExcludedGroups,
      options: _bound(owner),
      useSnapshots: false,
    );
    final data = _payload(response) as List<dynamic>;
    return Set.unmodifiable(
      data.map(
        (entry) => (entry as Map<String, dynamic>)['group_id'] as String,
      ),
    );
  }

  Future<bool> setGroupExcluded(
    String owner,
    String groupId,
    bool excluded,
  ) async {
    final path = ApiConstants.locationExcludedGroup(groupId);
    final response = excluded
        ? await _api.put<Map<String, dynamic>>(path, options: _bound(owner))
        : await _api.delete<Map<String, dynamic>>(path, options: _bound(owner));
    final data = _payload(response) as Map<String, dynamic>;
    if (data['group_id'] != groupId) {
      throw const FormatException('Invalid location exclusion response');
    }
    return data['excluded'] as bool;
  }
}
