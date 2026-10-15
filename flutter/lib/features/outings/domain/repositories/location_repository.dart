class LocationHit {
  const LocationHit({
    required this.name,
    required this.latitude,
    required this.longitude,
  });

  final String name;
  final double latitude;
  final double longitude;
}

abstract class LocationRepository {
  Future<String?> reverseGeocode({
    required double latitude,
    required double longitude,
  });

  Future<List<LocationHit>> search(String query);
}
