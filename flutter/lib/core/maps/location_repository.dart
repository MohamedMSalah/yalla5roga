class LocationHit {
  const LocationHit({
    required this.id,
    required this.name,
    required this.area,
    required this.latitude,
    required this.longitude,
  });

  final String id;
  final String name;
  final String area;
  final double latitude;
  final double longitude;
}

class LocationLookup {
  const LocationLookup({
    this.available = true,
    this.hits = const [],
    this.attribution,
    this.cacheSeconds = 0,
  });

  final bool available;
  final List<LocationHit> hits;
  final String? attribution;
  final int cacheSeconds;
}

abstract class LocationRepository {
  Future<LocationLookup> reverseGeocode({
    required double latitude,
    required double longitude,
    required String language,
    required Future<void> cancelled,
  });

  Future<LocationLookup> search(
    String query, {
    required String language,
    required Future<void> cancelled,
  });
}
