import 'package:dio/dio.dart';
import 'package:yalla_5roga/core/constants/api_constants.dart';
import 'package:yalla_5roga/core/network/api_client.dart';
import 'package:yalla_5roga/core/network/dio_interceptors.dart';

class SavedPlacesRemoteDataSource {
  SavedPlacesRemoteDataSource(this._api);

  final ApiClient _api;

  Future<List<String>> listSavedPlaceIds() async {
    final list = await listSavedPlaces();
    return list
        .map(
          (item) => item['place_id'] as String? ?? item['id'] as String? ?? '',
        )
        .where((id) => id.isNotEmpty)
        .toList();
  }

  Future<List<Map<String, dynamic>>> listSavedPlaces() async {
    final response = await _api.get(ApiConstants.savedPlaces);
    final raw = response.data;
    final list = raw is Map && raw['data'] is List
        ? raw['data'] as List
        : raw is List
        ? raw
        : const [];
    return list
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
  }

  Options _bound(String? owner) => Options(extra: {expectedUserIdKey: ?owner});

  Future<void> save(String placeId, {String? owner}) async {
    await _api.post(ApiConstants.savedPlace(placeId), options: _bound(owner));
  }

  Future<void> unsave(String placeId, {String? owner}) async {
    await _api.delete(ApiConstants.savedPlace(placeId), options: _bound(owner));
  }
}
