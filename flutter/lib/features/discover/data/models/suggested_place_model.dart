import 'package:yalla_5roga/core/network/api_payload.dart';
import 'package:yalla_5roga/features/discover/domain/entities/suggested_place.dart';
import 'package:yalla_5roga/features/place_reviews/data/models/place_rating_statistics_model.dart';

abstract final class SuggestedPlaceModel {
  static SuggestedPlace fromJson(Map<String, dynamic> json) {
    return SuggestedPlace(
      id: apiString(json['id']) ?? '',
      name: apiString(json['name']) ?? '',
      brandId: apiString(json['brand_id']) ?? '',
      brandName: apiString(json['brand_name']) ?? '',
      branchName: apiString(json['branch_name']) ?? '',
      branchCount: (json['branch_count'] as num?)?.toInt() ?? 0,
      ratingStatistics: PlaceRatingStatisticsModel.tryFromJson(
        json['rating_statistics'],
      ),
      categoryId: apiString(json['category_id']) ?? '',
      status: apiString(json['status']) ?? 'active',
      nameAr: apiString(json['name_ar']) ?? '',
      nameEn: apiString(json['name_en']) ?? '',
      source: apiString(json['source']) ?? 'manual',
      vibeIds:
          (json['vibes'] as List? ??
                  (json['place_vibes'] as List?)
                      ?.map((v) => v['vibe_id'])
                      .toList() ??
                  const [])
              .whereType<String>()
              .toList(),
      openingHours: apiString(json['opening_hours']) ?? '',
      website: apiString(json['website']) ?? '',
      phone: apiString(json['phone']) ?? '',
      address: apiString(json['address']) ?? '',
      area: apiString(json['area']) ?? '',
      vibe: OutingVibe.values.firstWhere(
        (item) => item.name == json['vibe'],
        orElse: () => OutingVibe.food,
      ),
      coverImageUrl:
          apiString(json['cover_image_url']) ??
          apiString(json['image_url']) ??
          apiString(json['coverImageUrl']) ??
          apiString(json['imageUrl']) ??
          '',
      description:
          apiString(json['description']) ??
          apiString(json['descriptionKey']) ??
          '',
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      featured: apiBool(json['featured']),
      distanceKm: (json['distance_km'] as num?)?.toDouble(),
      priceLevel: PriceLevel.values.firstWhere(
        (p) => p.name == json['price_level'],
        orElse: () => PriceLevel.moderate,
      ),
      priceMin: num.tryParse('${json['price_min']}')?.toDouble(),
      priceMax: num.tryParse('${json['price_max']}')?.toDouble(),
      currency: apiString(json['currency']) ?? 'EGP',
      images: (json['place_images'] as List? ?? const [])
          .whereType<Map>()
          .map(
            (v) => DiscoverPlaceImage(
              imageUrl: apiString(v['image_url']) ?? '',
              caption: apiString(v['caption']),
            ),
          )
          .toList(),
      hours: (json['place_hours'] as List? ?? const [])
          .whereType<Map>()
          .map(
            (v) => DiscoverPlaceHours(
              day: Weekday.values.firstWhere(
                (d) => d.name == v['day'],
                orElse: () => Weekday.monday,
              ),
              opensAt: apiString(v['opens_at']),
              closesAt: apiString(v['closes_at']),
              isClosed: apiBool(v['is_closed']),
            ),
          )
          .toList(),
      prices: (json['place_prices'] as List? ?? const [])
          .whereType<Map>()
          .map(
            (v) => DiscoverPlacePrice(
              labelKey: apiString(v['label']) ?? '',
              amount: num.tryParse('${v['amount']}')?.toDouble() ?? 0,
              currency: apiString(v['currency']) ?? 'EGP',
            ),
          )
          .toList(),
    );
  }
}
