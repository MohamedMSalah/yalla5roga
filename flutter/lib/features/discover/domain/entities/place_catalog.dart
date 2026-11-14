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
    this.latitude,
    this.longitude,
    this.radiusKm = 10,
  });
  final Set<String> categories, vibes;
  final String search;
  final double? latitude, longitude;
  final double radiusKm;
  Map<String, dynamic> query({int offset = 0}) => {
    'limit': 50,
    'offset': offset,
    'status': 'active',
    if (categories.isNotEmpty)
      'categories': (categories.toList()..sort()).join(','),
    if (vibes.isNotEmpty) 'vibes': (vibes.toList()..sort()).join(','),
    if (search.trim().isNotEmpty) 'search': search.trim(),
    if (latitude != null && longitude != null) ...{
      'lat': latitude,
      'lng': longitude,
      'radiusKm': radiusKm,
      'sort': 'distance',
    },
  };
  String key(int offset) => jsonEncode(query(offset: offset));
  PlaceFilters copyWith({
    Set<String>? categories,
    Set<String>? vibes,
    String? search,
    double? latitude,
    double? longitude,
    double? radiusKm,
    bool clearLocation = false,
  }) => PlaceFilters(
    categories: categories ?? this.categories,
    vibes: vibes ?? this.vibes,
    search: search ?? this.search,
    latitude: clearLocation ? null : latitude ?? this.latitude,
    longitude: clearLocation ? null : longitude ?? this.longitude,
    radiusKm: radiusKm ?? this.radiusKm,
  );
  bool matches(Place place) {
    if (place.status != 'active' ||
        (categories.isNotEmpty && !categories.contains(place.categoryId)) ||
        (vibes.isNotEmpty && !place.vibeIds.any(vibes.contains))) {
      return false;
    }
    if (!'${place.name} ${place.nameAr} ${place.nameEn} ${place.area} ${place.address}'
        .toLowerCase()
        .contains(search.trim().toLowerCase())) {
      return false;
    }
    if (latitude != null && longitude != null) {
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
