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
    this.featured = false,
    this.images = const [],
    this.hours = const [],
    this.prices = const [],
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
  final bool featured;
  final List<DiscoverPlaceImage> images;
  final List<DiscoverPlaceHours> hours;
  final List<DiscoverPlacePrice> prices;

  /// Compatibility alias used by older widgets.
  String get imageUrl => coverImageUrl;

  Place toOutingPlace() => Place(
    id: id,
    name: name,
    area: area,
    latitude: latitude,
    longitude: longitude,
    imageUrl: coverImageUrl,
    vibe: vibe,
  );

  /// Display helpers — values come from the API, not local seed maps.
  String localizedName(L10n l10n) => name;

  String localizedArea(L10n l10n) => l10n.suggestedArea(area);

  String localizedDescription(L10n l10n) => description;
}
