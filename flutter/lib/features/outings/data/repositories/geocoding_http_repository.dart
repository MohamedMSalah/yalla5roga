import 'package:dio/dio.dart';
import 'package:yalla_5roga/core/config/app_config.dart';
import 'package:yalla_5roga/core/constants/app_constants.dart';
import 'package:yalla_5roga/features/outings/domain/repositories/location_repository.dart';

abstract class GeocodingRemoteDataSource {
  Future<String?> reverseGeocode({
    required double latitude,
    required double longitude,
  });

  Future<List<LocationHit>> search(String query);
}

class GeocodingHttpDataSource implements GeocodingRemoteDataSource {
  GeocodingHttpDataSource({
    Dio? client,
    String? nominatimHost,
    Duration? timeout,
  }) : _nominatimHost = nominatimHost ?? AppConfig.instance.nominatimHost,
       _timeout = timeout ?? AppConfig.instance.connectTimeout,
       _client = client ?? Dio();

  final Dio _client;
  final String _nominatimHost;
  final Duration _timeout;

  Map<String, String> get _headers => {
    'User-Agent': AppConstants.nominatimUserAgent,
  };

  @override
  Future<String?> reverseGeocode({
    required double latitude,
    required double longitude,
  }) async {
    try {
      final response = await _client.get<dynamic>('https://$_nominatimHost/reverse', queryParameters: {
        'format': 'jsonv2',
        'lat': '$latitude',
        'lon': '$longitude',
      }, options: Options(headers: _headers),).timeout(_timeout);
      if (response.statusCode != 200) return null;
      final data = response.data;
      if (data is! Map) return null;
      final named = (data['name'] as String?)?.trim();
      if (named != null && named.isNotEmpty) return named;
      final display = (data['display_name'] as String?)?.trim();
      if (display == null || display.isEmpty) return null;
      return display.split(',').first.trim();
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<LocationHit>> search(String query) async {
    try {
      final response = await _client.get<dynamic>('https://$_nominatimHost/search', queryParameters: {
        'format': 'jsonv2',
        'q': query,
        'limit': '8',
      }, options: Options(headers: _headers),).timeout(_timeout);
      if (response.statusCode != 200) return const [];
      final data = response.data;
      if (data is! List) return const [];
      final hits = <LocationHit>[];
      for (final item in data) {
        if (item is! Map) continue;
        final lat = double.tryParse('${item['lat']}');
        final lon = double.tryParse('${item['lon']}');
        if (lat == null || lon == null) continue;
        final named = (item['name'] as String?)?.trim();
        final display = (item['display_name'] as String?)?.trim();
        final label = (named != null && named.isNotEmpty)
            ? named
            : (display == null || display.isEmpty
                  ? query
                  : display.split(',').first.trim());
        hits.add(LocationHit(name: label, latitude: lat, longitude: lon));
      }
      return hits;
    } catch (_) {
      return const [];
    }
  }
}

class GeocodingHttpRepository implements LocationRepository {
  GeocodingHttpRepository({GeocodingRemoteDataSource? remote})
    : _remote = remote ?? GeocodingHttpDataSource();

  final GeocodingRemoteDataSource _remote;

  @override
  Future<String?> reverseGeocode({
    required double latitude,
    required double longitude,
  }) {
    return _remote.reverseGeocode(latitude: latitude, longitude: longitude);
  }

  @override
  Future<List<LocationHit>> search(String query) => _remote.search(query);
}
