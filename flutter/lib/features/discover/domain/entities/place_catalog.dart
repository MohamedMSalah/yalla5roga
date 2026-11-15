import 'dart:convert';
import 'dart:math' as math;

import 'package:yalla_5roga/features/outings/domain/entities/place.dart';

class CatalogDefinition {
  const CatalogDefinition({
    required this.id,
    required this.nameEn,
    required this.nameAr,
    required this.icon,
    this.group = '',
  });
  final String id, nameEn, nameAr, icon, group;
  factory CatalogDefinition.fromJson(Map<String, dynamic> json) =>
      CatalogDefinition(
        id: json['id'] as String,
        nameEn: json['name_en'] as String,
        nameAr: json['name_ar'] as String,
        icon: json['icon'] as String? ?? 'place',
        group: json['group_id'] as String? ?? '',
      );
  String label(String language) => language == 'ar' ? nameAr : nameEn;
}

/// One filter policy for Discover, outing suggestions and map selection.
class PlaceFilters {
  const PlaceFilters({
    this.categories = const {},
    this.vibes = const {},
    this.search = '',
    this.brandId,
    this.latitude,
    this.longitude,
    this.radiusKm = 10,
    this.bounds,
  });
  final Set<String> categories, vibes;
  final String search;
  final String? brandId;
  final double? latitude, longitude;
  final double radiusKm;

  /// west,south,east,north as accepted by the existing catalog API.
  final String? bounds;
  Map<String, dynamic> query({int offset = 0}) => {
    'limit': 50,
    'offset': offset,
    'status': 'active',
    if (brandId != null) 'brand_id': brandId,
    if (bounds != null) 'bbox': bounds,
    if (categories.isNotEmpty)
      'categories': (categories.toList()..sort()).join(','),
    if (vibes.isNotEmpty) 'vibes': (vibes.toList()..sort()).join(','),
    if (search.trim().isNotEmpty) 'search': search.trim(),
    if (latitude != null && longitude != null) ...{
      'lat': latitude,
      'lng': longitude,
      if (brandId == null) 'radiusKm': radiusKm,
      'sort': 'distance',
    },
  };
  String key(int offset) => jsonEncode(query(offset: offset));
  PlaceFilters copyWith({
    String? brandId,
    Set<String>? categories,
    Set<String>? vibes,
    String? search,
    double? latitude,
    double? longitude,
    double? radiusKm,
    bool clearLocation = false,
    String? bounds,
    bool clearBounds = false,
  }) => PlaceFilters(
    brandId: brandId ?? this.brandId,
    categories: categories ?? this.categories,
    vibes: vibes ?? this.vibes,
    search: search ?? this.search,
    latitude: clearLocation ? null : latitude ?? this.latitude,
    longitude: clearLocation ? null : longitude ?? this.longitude,
    radiusKm: radiusKm ?? this.radiusKm,
    bounds: clearBounds ? null : bounds ?? this.bounds,
  );
  bool matches(Place place) {
    if ((brandId != null && brandId != place.brandId) ||
        place.status != 'active' ||
        (categories.isNotEmpty && !categories.contains(place.categoryId)) ||
        (vibes.isNotEmpty && !place.vibeIds.any(vibes.contains))) {
      return false;
    }
    if (!'${place.name} ${place.nameAr} ${place.nameEn} ${place.area} ${place.address}'
        .toLowerCase()
        .contains(search.trim().toLowerCase())) {
      return false;
    }
    if (bounds case final value?) {
      final box = value.split(',').map(double.parse).toList();
      if (!place.hasCoordinates ||
          place.longitude! < box[0] ||
          place.latitude! < box[1] ||
          place.longitude! > box[2] ||
          place.latitude! > box[3]) {
        return false;
      }
    }
    if (brandId == null && latitude != null && longitude != null) {
      if (!place.hasCoordinates) return false;
      const rad = math.pi / 180;
      final a =
          math.pow(math.sin((place.latitude! - latitude!) * rad / 2), 2) +
          math.cos(latitude! * rad) *
              math.cos(place.latitude! * rad) *
              math.pow(math.sin((place.longitude! - longitude!) * rad / 2), 2);
      if (6371.0088 * 2 * math.asin(math.sqrt(a.clamp(0, 1))) > radiusKm) {
        return false;
      }
    }
    return true;
  }
}
