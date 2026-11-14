import 'package:yalla_5roga/core/localization/l10n.dart';
import 'package:yalla_5roga/features/outings/domain/entities/outing_enums.dart';
import 'package:yalla_5roga/features/outings/domain/entities/place.dart';

export 'package:yalla_5roga/features/outings/domain/entities/outing_enums.dart'
    show OutingVibe;

enum PriceLevel { free, budget, moderate, expensive, luxury }

enum Weekday { monday, tuesday, wednesday, thursday, friday, saturday, sunday }

class DiscoverPlaceImage {
  const DiscoverPlaceImage({required this.imageUrl, this.caption});

  final String imageUrl;
  final String? caption;
}

class DiscoverPlaceHours {
  const DiscoverPlaceHours({
    required this.day,
    this.opensAt,
    this.closesAt,
    this.isClosed = false,
  });

  final Weekday day;
  final String? opensAt;
  final String? closesAt;
  final bool isClosed;
}

class DiscoverPlacePrice {
  const DiscoverPlacePrice({
    required this.labelKey,
    required this.amount,
    this.currency = 'EGP',
  });

  final String labelKey;
  final double amount;
  final String currency;
}

class SuggestedPlace {
  const SuggestedPlace({
    required this.id,
    required this.name,
    required this.area,
    required this.vibe,
    required this.coverImageUrl,
    this.description = '',
    this.priceLevel = PriceLevel.moderate,
    this.priceMin,
    this.priceMax,
    this.currency = 'EGP',
    this.latitude,
    this.longitude,
    this.distanceKm,
    this.featured = false,
    this.images = const [],
    this.hours = const [],
    this.prices = const [],
    this.categoryId = '',
    this.vibeIds = const [],
    this.status = 'active',
    this.nameAr = '',
    this.nameEn = '',
    this.source = 'manual',
    this.openingHours = '',
    this.website = '',
    this.phone = '',
    this.address = '',
  });

  final String id;
  final String name;
  final String area;
  final OutingVibe vibe;
  final String coverImageUrl;
  final String description;
  final PriceLevel priceLevel;
  final double? priceMin;
  final double? priceMax;
  final String currency;
  final double? latitude;
  final double? longitude;
  final double? distanceKm;
  final bool featured;
  final List<DiscoverPlaceImage> images;
  final List<DiscoverPlaceHours> hours;
  final List<DiscoverPlacePrice> prices;
  final String categoryId,
      status,
      nameAr,
      nameEn,
      source,
      openingHours,
      website,
      phone,
      address;
  final List<String> vibeIds;

  /// Compatibility alias used by older widgets.
  String get imageUrl => coverImageUrl;
  bool get hasKnownPrice =>
      source != 'osm' || priceMin != null || priceMax != null;
  String localizedSummary(L10n l10n) => [
    localizedArea(l10n),
    if (hasKnownPrice) l10n.priceLevelLabel(priceLevel.name),
  ].where((v) => v.trim().isNotEmpty).join(' · ');

  Place toOutingPlace() => Place(
    id: id,
    name: name,
    area: area,
    latitude: latitude,
    longitude: longitude,
    imageUrl: coverImageUrl,
    vibe: vibe,
    categoryId: categoryId,
    vibeIds: vibeIds,
    status: status,
    nameAr: nameAr,
    nameEn: nameEn,
    address: address,
  );

  /// Display helpers — values come from the API, not local seed maps.
  String localizedName(L10n l10n) =>
      l10n.locale.languageCode == 'ar' && nameAr.isNotEmpty
      ? nameAr
      : l10n.locale.languageCode == 'en' && nameEn.isNotEmpty
      ? nameEn
      : name;

  String localizedArea(L10n l10n) => l10n.suggestedArea(area);

  String localizedDescription(L10n l10n) => description;
}
