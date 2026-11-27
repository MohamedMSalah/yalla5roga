import 'package:yalla_5roga/features/discover/data/datasources/saved_places_remote_datasource.dart';
import 'package:dio/dio.dart';
import 'package:yalla_5roga/features/discover/data/models/suggested_place_model.dart';
import 'package:yalla_5roga/core/constants/api_constants.dart';
import 'package:yalla_5roga/core/error/exceptions.dart';
import 'package:yalla_5roga/core/network/api_client.dart';
import 'package:yalla_5roga/core/network/diagnostics/request_scope.dart';
import 'package:yalla_5roga/core/network/api_payload.dart';
import 'package:yalla_5roga/features/discover/domain/entities/suggested_place.dart';
import 'package:yalla_5roga/features/discover/domain/repositories/discover_repository.dart';
import 'package:yalla_5roga/features/outings/domain/entities/place.dart';

abstract class DiscoverDataSource {
  Future<List<SuggestedPlace>> getNearbyPlaces({
    required double latitude,
    required double longitude,
    OutingVibe? vibe,
  });

  Future<List<SuggestedPlace>> getPlaces({OutingVibe? vibe});
  Future<List<SuggestedPlace>> getFeaturedPlaces();
  Future<SuggestedPlace> getPlace(String placeId);
  List<Place> catalogPlaces();
}

class DiscoverRemoteDataSource implements DiscoverDataSource {
  DiscoverRemoteDataSource(this._client);

  final ApiClient _client;
  String? get savedPlacesOwner => _client.snapshots?.userId();
  Future<List<Map<String, dynamic>>> recommendations({
    String? latitude,
    String? longitude,
  }) async {
    try {
      final response = await _client.get<Map<String, dynamic>>(
        '${ApiConstants.places}/recommendations',
        queryParameters: {'lat': ?latitude, 'lng': ?longitude},
        publicRead: true,
        useSnapshots: false,
      );
      return apiObjectList(response.data);
    } on DioException catch (error) {
      throw _unwrap(error);
    }
  }

  Future<String?> catalogVersion() async {
    final response = await _client.get<Map<String, dynamic>>(
      '${ApiConstants.places}/version',
      publicRead: true,
      useSnapshots: false,
    );
    return response.data?['data']?['version'] as String?;
  }

  Future<List<SuggestedPlace>> savedPlaces() async {
    try {
      final rows = await SavedPlacesRemoteDataSource(_client).listSavedPlaces();
      return rows
          .where((row) => row['places'] is Map)
          .map(
            (row) =>
                parsePlace(Map<String, dynamic>.from(row['places'] as Map)),
          )
          .toList();
    } on DioException catch (e) {
      throw _unwrap(e);
    }
  }

  Future<void> setSaved(String id, bool saved, {required String owner}) async {
    try {
      if (saved) {
        await SavedPlacesRemoteDataSource(_client).save(id, owner: owner);
      } else {
        await SavedPlacesRemoteDataSource(_client).unsave(id, owner: owner);
      }
    } on DioException catch (e) {
      throw _unwrap(e);
    }
  }

  Future<Map<String, dynamic>> catalogChanges(String? cursor) async {
    final response = await _client.get<Map<String, dynamic>>(
      '${ApiConstants.places}/changes',
      queryParameters: {'cursor': ?cursor, 'limit': 500},
      publicRead: true,
    );
    return apiPayload(response.data);
  }

  Future<List<Map<String, dynamic>>> definitionRecords(String kind) async {
    final response = await _client.get<Map<String, dynamic>>(
      '${ApiConstants.places}/$kind',
    );
    return apiObjectList(response.data);
  }

  Future<List<Map<String, dynamic>>> queryRecords(
    Map<String, dynamic> query, {
    bool useSnapshots = true,
    Future<void>? cancelled,
  }) async => apiObjectList(
    await _queryCatalog(
      query,
      useSnapshots: useSnapshots,
      cancelled: cancelled,
    ),
  );

  Future<RatingPlacePage> ratingPage(
    Map<String, dynamic> query, {
    Future<void>? cancelled,
  }) async {
    final body = await _queryCatalog(
      query,
      useSnapshots: false,
      cancelled: cancelled,
    );
    final pagination = body?['pagination'];
    if (pagination is! Map<String, dynamic>) throw const ParseException();
    final next = pagination['next_cursor'] as String?;
    final available = pagination['rating_ranking_available'] as bool?;
    if (pagination['has_more'] != (next != null) ||
        (query['sort'] == 'top_rated' && available == null)) {
      throw const ParseException();
    }
    return (
      places: apiObjectList(body).map(parsePlace).toList(growable: false),
      nextCursor: next,
      rankingAvailable: available,
    );
  }

  Future<Map<String, dynamic>?> _queryCatalog(
    Map<String, dynamic> query, {
    required bool useSnapshots,
    Future<void>? cancelled,
  }) async {
    try {
      final token = cancelled == null ? null : CancelToken();
      if (token != null) cancelled!.then((_) => token.cancel());
      final response = await _client.get<Map<String, dynamic>>(
        ApiConstants.places,
        queryParameters: query,
        useSnapshots: useSnapshots,
        publicRead: !useSnapshots,
        cancelToken: token,
      );
      return response.data;
    } on DioException catch (error) {
      if (CancelToken.isCancel(error)) throw const NetworkException();
      throw _unwrap(error);
    }
  }

  Future<({List<Map<String, dynamic>> rows, String? cursor})> areaPage(
    String bounds,
    String? cursor, {
    bool compact = false,
    Future<void>? cancelled,
  }) async {
    final token = cancelled == null ? null : CancelToken();
    if (token != null) cancelled!.then((_) => token.cancel());
    final response = await RequestScope.run(
      () => _client.get<Map<String, dynamic>>(
        ApiConstants.places,
        queryParameters: {
          'bbox': bounds,
          'limit': 100,
          if (compact) 'sort': 'id',
          if (compact) 'compact': 'true' else 'details': 'true',
          'cursor': ?cursor,
        },
        useSnapshots: false,
        publicRead: true,
        cancelToken: token,
      ),
      origin: 'DiscoverRemoteDataSource',
      feature: 'Discover',
      trigger: cursor != null
          ? 'pagination'
          : compact
          ? 'viewport_changed'
          : 'background_sync',
    );
    if (response.data?['success'] != true) {
      throw const FormatException('Invalid geographic response');
    }
    final pagination = response.data!['pagination'] as Map<String, dynamic>;
    final rows = response.data!['data'] as List;
    final more = pagination['has_more'] as bool;
    final next = pagination['next_cursor'] as String?;
    final [west, south, east, north] = bounds
        .split(',')
        .map(double.parse)
        .toList();
    if (more != (next != null) ||
        more && rows.length != 100 ||
        rows.length > 100 ||
        rows.any((row) {
          if (row is! Map<String, dynamic> ||
              row['id'] is! String ||
              row['status'] != 'active') {
            return true;
          }
          final lat = row['latitude'];
          final lng = row['longitude'];
          return lat is! num ||
              lng is! num ||
              !lat.isFinite ||
              !lng.isFinite ||
              lat < south ||
              lat > north ||
              (west < east
                  ? lng < west || lng > east
                  : lng < west && lng > east);
        })) {
      throw const FormatException('Invalid geographic page');
    }
    return (
      rows: rows.cast<Map<String, dynamic>>(),
      cursor: pagination['next_cursor'] as String?,
    );
  }

  Future<Map<String, dynamic>> placeRecord(
    String id, {
    bool useSnapshots = true,
  }) async {
    try {
      final response = await _client.get<Map<String, dynamic>>(
        ApiConstants.place(id),
        useSnapshots: useSnapshots,
        publicRead: !useSnapshots,
      );
      return apiPayload(response.data);
    } on DioException catch (error) {
      throw _unwrap(error);
    }
  }

  @override
  Future<List<SuggestedPlace>> getNearbyPlaces({
    required double latitude,
    required double longitude,
    OutingVibe? vibe,
  }) async {
    try {
      final response = await _client.get<Map<String, dynamic>>(
        ApiConstants.nearbyPlaces,
        queryParameters: {
          'lat': latitude,
          'lng': longitude,
          'limit': 6,
          if (vibe != null) 'vibe': vibe.name,
        },
      );
      return apiObjectList(
        response.data,
        aliases: const ['places', 'items'],
      ).map(parsePlace).toList();
    } on DioException catch (error) {
      throw _unwrap(error);
    }
  }

  @override
  Future<List<SuggestedPlace>> getPlaces({OutingVibe? vibe}) async {
    try {
      final response = await _client.get<Map<String, dynamic>>(
        ApiConstants.places,
        queryParameters: vibe == null ? null : {'vibe': vibe.name},
      );
      final items = apiObjectList(
        response.data,
        aliases: const ['places', 'items'],
      );
      return [for (final item in items) parsePlace(item)];
    } on DioException catch (error) {
      throw _unwrap(error);
    }
  }

  @override
  Future<List<SuggestedPlace>> getFeaturedPlaces() async {
    try {
      final response = await _client.get<Map<String, dynamic>>(
        ApiConstants.places,
        queryParameters: {'featured': 'true', 'limit': 50},
      );
      return apiObjectList(response.data).map(parsePlace).toList();
    } on DioException catch (error) {
      throw _unwrap(error);
    }
  }

  @override
  Future<SuggestedPlace> getPlace(String placeId) async {
    try {
      final response = await _client.get<Map<String, dynamic>>(
        ApiConstants.place(placeId),
      );
      return parsePlace(apiPayload(response.data));
    } on DioException catch (error) {
      throw _unwrap(error);
    }
  }

  @override
  List<Place> catalogPlaces() => const [];

  SuggestedPlace parsePlace(Map<String, dynamic> json) =>
      SuggestedPlaceModel.fromJson(json);

  AppException _unwrap(DioException error) {
    if (error.error is AppException) return error.error as AppException;
    return ServerException(
      error.message ?? 'Server error',
      null,
      error.response?.statusCode,
    );
  }
}
