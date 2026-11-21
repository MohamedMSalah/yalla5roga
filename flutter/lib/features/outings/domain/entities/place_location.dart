/// Final / saved location snapshot for an outing.
class PlaceLocation {
  const PlaceLocation({
    required this.name,
    this.placeId,
    this.address = '',
    this.categoryId = '',
    this.area = '',
    this.latitude,
    this.longitude,
  });

  final String name, categoryId, address;
  final String? placeId;
  final String area;
  final double? latitude;
  final double? longitude;

  bool get hasCoordinates => latitude != null && longitude != null;

  String get vicinity => address.isNotEmpty ? address : area;
  String get label => vicinity.isEmpty ? name : '$name, $vicinity';

  Map<String, dynamic> toJson() => {
    'name': name,
    if (categoryId.isNotEmpty) 'category_id': categoryId,
    if (address.isNotEmpty) 'address': address,
    if (placeId != null) 'placeId': placeId,
    'area': area,
    'latitude': latitude,
    'longitude': longitude,
  };

  factory PlaceLocation.fromJson(Map<String, dynamic> json) {
    return PlaceLocation(
      categoryId: json['category_id'] as String? ?? '',
      address: json['address'] as String? ?? '',
      name: json['name'] as String? ?? '',
      placeId: json['placeId'] as String?,
      area: json['area'] as String? ?? '',
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
    );
  }
}

/// Backward-compatible alias used across existing UI.
typedef OutingLocation = PlaceLocation;
