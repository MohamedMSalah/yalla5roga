import 'package:dio/dio.dart';
import 'package:yalla_5roga/core/constants/api_constants.dart';
import 'package:yalla_5roga/core/error/exceptions.dart';
import 'package:yalla_5roga/core/network/api_client.dart';
import 'package:yalla_5roga/core/network/api_payload.dart';
import 'package:yalla_5roga/features/discover/domain/entities/suggested_place.dart';
import 'package:yalla_5roga/features/outings/domain/entities/place.dart';

abstract class DiscoverDataSource {
  Future<List<SuggestedPlace>> getPlaces({OutingVibe? vibe});
  Future<List<SuggestedPlace>> getFeaturedPlaces();
  Future<SuggestedPlace> getPlace(String placeId);
  List<Place> catalogPlaces();
}

class DiscoverRemoteDataSource implements DiscoverDataSource {
  DiscoverRemoteDataSource(this._client);

  final ApiClient _client;

  @override
  Future<List<SuggestedPlace>> getPlaces({OutingVibe? vibe}) async {
    try {
      final response = await _client.get<Map<String, dynamic>>(
        ApiConstants.places,
        queryParameters: vibe == null ? null : {'vibe': vibe.name},
      );
      final payload = apiPayload(response.data);
      final raw = payload['items'] ?? payload['places'] ?? payload;
      if (raw is! List) return const [];
      return [
        for (final item in raw)
          if (item is Map) _fromJson(Map<String, dynamic>.from(item)),
      ];
    } on DioException catch (error) {
      throw _unwrap(error);
    }
  }

  @override
  Future<List<SuggestedPlace>> getFeaturedPlaces() async {
    final places = await getPlaces();
    return [
      for (final place in places)
        if (place.featured) place,
    ];
  }

  @override
  Future<SuggestedPlace> getPlace(String placeId) async {
    try {
      final response = await _client.get<Map<String, dynamic>>(
        ApiConstants.place(placeId),
      );
      return _fromJson(apiPayload(response.data));
    } on DioException catch (error) {
      throw _unwrap(error);
    }
  }

  @override
  List<Place> catalogPlaces() => const [];

  SuggestedPlace _fromJson(Map<String, dynamic> json) {
    return SuggestedPlace(
      id: apiString(json['id']) ?? '',
      name: apiString(json['name']) ?? '',
      area: apiString(json['area']) ?? '',
      vibe: OutingVibe.values.firstWhere(
        (item) => item.name == json['vibe'],
        orElse: () => OutingVibe.food,
      ),
      coverImageUrl:
          apiString(json['coverImageUrl']) ?? apiString(json['imageUrl']) ?? '',
      description:
          apiString(json['description']) ??
          apiString(json['descriptionKey']) ??
          '',
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      featured: apiBool(json['featured']),
    );
  }

  AppException _unwrap(DioException error) {
    if (error.error is AppException) return error.error as AppException;
    return ServerException(error.message ?? 'Server error');
  }
}
