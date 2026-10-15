/// Final / saved location snapshot for an outing.
class PlaceLocation {
  const PlaceLocation({
    required this.name,
    this.area = '',
    this.latitude,
    this.longitude,
  });

  final String name;
  final String area;
  final double? latitude;
  final double? longitude;

  bool get hasCoordinates => latitude != null && longitude != null;

  String get label => area.isEmpty ? name : '$name, $area';

  Map<String, dynamic> toJson() => {
    'name': name,
    'area': area,
    'latitude': latitude,
    'longitude': longitude,
  };

  factory PlaceLocation.fromJson(Map<String, dynamic> json) {
    return PlaceLocation(
      name: json['name'] as String? ?? '',
      area: json['area'] as String? ?? '',
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
    );
  }
}

/// Backward-compatible alias used across existing UI.
typedef OutingLocation = PlaceLocation;
