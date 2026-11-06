import 'package:yalla_5roga/core/constants/api_constants.dart';
import 'package:yalla_5roga/core/network/api_client.dart';

class SavedPlacesRemoteDataSource {
  SavedPlacesRemoteDataSource(this._api);

  final ApiClient _api;

  Future<List<String>> listSavedPlaceIds() async {
    final response = await _api.get(ApiConstants.savedPlaces);
    final raw = response.data;
    final list = raw is Map && raw['data'] is List
        ? raw['data'] as List
        : raw is List
        ? raw
        : const [];
    return list
        .whereType<Map>()
        .map(
          (item) =>
              item['place_id'] as String? ?? item['id'] as String? ?? '',
        )
        .where((id) => id.isNotEmpty)
        .toList();
  }

  Future<void> save(String placeId) async {
    await _api.post(ApiConstants.savedPlace(placeId));
  }

  Future<void> unsave(String placeId) async {
    await _api.delete(ApiConstants.savedPlace(placeId));
  }
}
