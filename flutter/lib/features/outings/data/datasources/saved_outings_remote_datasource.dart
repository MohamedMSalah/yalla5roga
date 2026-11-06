import 'package:yalla_5roga/core/constants/api_constants.dart';
import 'package:yalla_5roga/core/network/api_client.dart';
import 'package:yalla_5roga/features/outings/domain/entities/place_location.dart';
import 'package:yalla_5roga/features/outings/domain/entities/saved_outing.dart';

class SavedOutingsRemoteDataSource {
  SavedOutingsRemoteDataSource(this._api);

  final ApiClient _api;

  Future<List<SavedOuting>> getSaved() async {
    final response = await _api.get(ApiConstants.savedOutings);
    final raw = response.data;
    final list = raw is Map && raw['data'] is List
        ? raw['data'] as List
        : raw is List
        ? raw
        : const [];
    return list
        .whereType<Map>()
        .map((item) => _mapSaved(item.cast<String, dynamic>()))
        .where((outing) => outing.id.isNotEmpty)
        .toList();
  }

  Future<void> save(String outingId) async {
    await _api.post(ApiConstants.savedOuting(outingId));
  }

  Future<void> unsave(String outingId) async {
    await _api.delete(ApiConstants.savedOuting(outingId));
  }

  SavedOuting _mapSaved(Map<String, dynamic> json) {
    final outing = (json['outing'] as Map?)?.cast<String, dynamic>();
    final id =
        outing?['id'] as String? ??
        json['outing_id'] as String? ??
        json['id'] as String? ??
        '';
    final title = outing?['title'] as String? ?? json['title'] as String? ?? '';
    final image =
        outing?['image_url'] as String? ?? json['image'] as String? ?? '';
    final locationName =
        outing?['location_name'] as String? ??
        (json['location'] is Map
            ? (json['location'] as Map)['name'] as String?
            : null) ??
        '';
    final lat = outing?['location_latitude'];
    final lng = outing?['location_longitude'];
    return SavedOuting(
      id: id,
      title: title,
      image: image,
      location: PlaceLocation(
        name: locationName,
        latitude: lat is num ? lat.toDouble() : null,
        longitude: lng is num ? lng.toDouble() : null,
      ),
    );
  }
}
