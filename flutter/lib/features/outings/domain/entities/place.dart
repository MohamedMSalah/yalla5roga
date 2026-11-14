import 'package:yalla_5roga/features/outings/domain/entities/outing_enums.dart';
import 'package:yalla_5roga/features/outings/domain/entities/place_location.dart';

/// Canonical place used by outings, votes, catalogs, and maps.
class Place {
  const Place({
    required this.name,
    required this.area,
    this.id = '',
    this.sourceId = '',
    this.latitude,
    this.longitude,
    this.imageUrl = '',
    this.vibe = OutingVibe.food,
    this.categoryId = '',
    this.vibeIds = const [],
    this.status = 'active',
    this.nameAr = '',
    this.nameEn = '',
    this.address = '',
  });

  /// Stable id when known; otherwise [placeId] derives a slug from [name].
  final String id;

  // Ephemeral geocoder identity. Only the selected snapshot is persisted.
  final String sourceId;
  final String name;
  final String area;
  final double? latitude;
  final double? longitude;

  /// Cover image from the API when available.
  final String imageUrl;

  /// Category used for fallback icons when [imageUrl] is empty.
  final OutingVibe vibe;
  final String categoryId, status, nameAr, nameEn, address;
  final List<String> vibeIds;

  String get placeId => id.isNotEmpty ? id : slugForName(name);

  bool get hasCoordinates => latitude != null && longitude != null;
  String displayName(String language) => language == 'ar' && nameAr.isNotEmpty
      ? nameAr
      : language == 'en' && nameEn.isNotEmpty
      ? nameEn
      : name;

  PlaceLocation toLocation() => PlaceLocation(
    placeId: id.isEmpty ? null : id,
    name: name,
    area: area,
    latitude: latitude,
    longitude: longitude,
  );

  Place copyWith({
    String? id,
    String? name,
    String? area,
    double? latitude,
    double? longitude,
    String? imageUrl,
    OutingVibe? vibe,
  }) {
    return Place(
      id: id ?? this.id,
      sourceId: sourceId,
      name: name ?? this.name,
      area: area ?? this.area,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      imageUrl: imageUrl ?? this.imageUrl,
      vibe: vibe ?? this.vibe,
      categoryId: categoryId,
      vibeIds: vibeIds,
      status: status,
      nameAr: nameAr,
      nameEn: nameEn,
      address: address,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'area': area,
    'latitude': latitude,
    'longitude': longitude,
    'imageUrl': imageUrl,
    'vibe': vibe.name,
    'category_id': categoryId,
    'vibes': vibeIds,
    'status': status,
    'name_ar': nameAr,
    'name_en': nameEn,
    'address': address,
  };

  factory Place.fromJson(Map<String, dynamic> json) {
    return Place(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      categoryId: json['category_id'] as String? ?? '',
      status: json['status'] as String? ?? 'active',
      nameAr: json['name_ar'] as String? ?? '',
      nameEn: json['name_en'] as String? ?? '',
      address: json['address'] as String? ?? '',
      vibeIds: (json['vibes'] as List? ?? const [])
          .whereType<String>()
          .toList(),
      area: json['area'] as String? ?? '',
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      imageUrl:
          json['imageUrl'] as String? ?? json['coverImageUrl'] as String? ?? '',
      vibe: OutingVibe.values.firstWhere(
        (item) => item.name == json['vibe'],
        orElse: () => OutingVibe.food,
      ),
    );
  }

  bool matchesSelection(Place other) {
    if (id.isNotEmpty && other.id.isNotEmpty) return id == other.id;
    if (sourceId.isNotEmpty && other.sourceId.isNotEmpty) {
      return sourceId == other.sourceId;
    }
    if (name.trim().toLowerCase() != other.name.trim().toLowerCase()) {
      return false;
    }
    if (area.isNotEmpty &&
        other.area.isNotEmpty &&
        area.trim().toLowerCase() != other.area.trim().toLowerCase()) {
      return false;
    }
    if (!hasCoordinates || !other.hasCoordinates) {
      return !hasCoordinates && !other.hasCoordinates && area == other.area;
    }
    return (latitude! - other.latitude!).abs() < .00005 &&
        (longitude! - other.longitude!).abs() < .00005;
  }

  static String slugForName(String name) {
    final lower = name.toLowerCase().trim();
    return lower
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');
  }

  @override
  bool operator ==(Object other) {
    return other is Place && other.placeId == placeId;
  }

  @override
  int get hashCode => placeId.hashCode;
}

/// Backward-compatible alias used across existing UI.
typedef OutingPlace = Place;
