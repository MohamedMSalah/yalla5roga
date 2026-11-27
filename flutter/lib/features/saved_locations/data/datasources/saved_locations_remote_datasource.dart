import 'package:dio/dio.dart';
import 'package:yalla_5roga/core/constants/api_constants.dart';
import 'package:yalla_5roga/core/network/api_client.dart';
import 'package:yalla_5roga/core/network/dio_interceptors.dart';

import 'package:yalla_5roga/features/transportation/domain/entities/transportation_preference.dart';
import 'package:yalla_5roga/features/transportation/domain/entities/routing_capabilities.dart';
import 'package:yalla_5roga/features/transportation/data/models/transportation_preference_model.dart';
import 'package:yalla_5roga/features/transportation/data/models/routing_capabilities_model.dart';

import '../../domain/entities/default_starting_location.dart';
import '../../domain/entities/saved_location.dart';
import '../models/default_starting_location_model.dart';
import '../models/saved_location_model.dart';

class SavedLocationsRemoteDataSource {
  const SavedLocationsRemoteDataSource(this._api);

  final ApiClient _api;

  Options _bound(String owner) => Options(extra: {expectedUserIdKey: owner});

  Future<Object?> _read(String owner, String path) async {
    final response = await _api.get<Map<String, dynamic>>(
      path,
      options: _bound(owner),
      useSnapshots: false,
    );
    return _payload(response);
  }

  Object? _payload(Response<Map<String, dynamic>> response) {
    final json = response.data;
    if (json == null || json['success'] != true || !json.containsKey('data')) {
      throw const FormatException('Invalid saved locations response');
    }
    return json['data'];
  }

  Future<List<SavedLocation>> list(String owner) async {
    final data = await _read(owner, ApiConstants.savedLocations) as List;
    return List.unmodifiable(
      data.map(
        (item) => SavedLocationModel.fromJson(item as Map<String, dynamic>),
      ),
    );
  }

  Future<SavedLocation> get(String owner, String id) async =>
      SavedLocationModel.fromJson(
        await _read(owner, ApiConstants.savedLocation(id))
            as Map<String, dynamic>,
      );

  Future<SavedLocation> create(String owner, SavedLocationDraft draft) async {
    final response = await _api.post<Map<String, dynamic>>(
      ApiConstants.savedLocations,
      data: SavedLocationModel.toJson(draft),
      options: _bound(owner),
    );
    return SavedLocationModel.fromJson(
      _payload(response) as Map<String, dynamic>,
    );
  }

  Future<SavedLocation> update(
    String owner,
    String id,
    SavedLocationDraft draft,
  ) async {
    final response = await _api.patch<Map<String, dynamic>>(
      ApiConstants.savedLocation(id),
      data: SavedLocationModel.toJson(draft),
      options: _bound(owner),
    );
    return SavedLocationModel.fromJson(
      _payload(response) as Map<String, dynamic>,
    );
  }

  Future<void> delete(String owner, String id) async {
    await _api.delete(ApiConstants.savedLocation(id), options: _bound(owner));
  }

  Future<DefaultStartingLocation?> getDefault(String owner) async {
    final data = await _read(owner, ApiConstants.defaultStartingLocation);
    return data == null
        ? null
        : DefaultStartingLocationModel.fromJson(data as Map<String, dynamic>);
  }

  Future<DefaultStartingLocation> setDefault(
    String owner,
    StartingLocationSource source,
    String id,
  ) async {
    final response = await _api.put<Map<String, dynamic>>(
      ApiConstants.defaultStartingLocation,
      data: DefaultStartingLocationModel.selection(source, id),
      options: _bound(owner),
    );
    return DefaultStartingLocationModel.fromJson(
      _payload(response) as Map<String, dynamic>,
    );
  }

  Future<TransportationPreference> getTransportationPreference(
    String owner,
  ) async => TransportationPreferenceModel.fromJson(
    await _read(owner, ApiConstants.transportationPreferences)
        as Map<String, dynamic>,
  );

  Future<TransportationPreference> updateTransportationPreference(
    String owner,
    TransportationMode? mode,
  ) async {
    final response = await _api.patch<Map<String, dynamic>>(
      ApiConstants.transportationPreferences,
      data: TransportationPreferenceModel.accountPatch(mode),
      options: _bound(owner),
    );
    return TransportationPreferenceModel.fromJson(
      _payload(response) as Map<String, dynamic>,
    );
  }

  Future<List<RoutingCapabilities>> getRoutingCapabilities(String owner) async {
    final data = await _read(owner, ApiConstants.routingCapabilities) as List;
    return List.unmodifiable(
      data
          .map(
            (item) =>
                RoutingCapabilitiesModel.fromJson(item as Map<String, dynamic>),
          )
          .whereType<RoutingCapabilities>(),
    );
  }

  Future<TransportationMode?> updateBookmarkTransportation(
    String owner,
    String id,
    TransportationMode? mode,
  ) async {
    final response = await _api.patch<Map<String, dynamic>>(
      ApiConstants.savedPlace(id),
      data: TransportationPreferenceModel.locationPatch(mode),
      options: _bound(owner),
    );
    final data = _payload(response) as Map<String, dynamic>;
    return TransportationPreferenceModel.modeFromJson(
      data['preferred_transportation_mode'],
    );
  }

  Future<void> clearDefault(String owner) async {
    await _api.delete(
      ApiConstants.defaultStartingLocation,
      options: _bound(owner),
    );
  }
}
