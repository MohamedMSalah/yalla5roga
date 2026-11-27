import '../../domain/entities/place_rating_statistics.dart';

abstract final class PlaceRatingStatisticsModel {
  static PlaceRatingStatistics? tryFromJson(Object? value) {
    if (value == null) return null;
    if (value is! Map<String, dynamic>) return null;
    try {
      return fromJson(value);
    } on FormatException {
      return null;
    } on TypeError {
      return null;
    }
  }

  static PlaceRatingStatistics fromJson(Map<String, dynamic> json) {
    final distribution = json['distribution'] as Map<String, dynamic>;
    final updatedAt = json['updatedAt'] as String?;
    return PlaceRatingStatistics(
      averageRating: (json['averageRating'] as num?)?.toDouble(),
      ratingCount: json['ratingCount'] as int,
      writtenReviewCount: json['writtenReviewCount'] as int,
      distribution: RatingDistribution(
        one: distribution['1'] as int,
        two: distribution['2'] as int,
        three: distribution['3'] as int,
        four: distribution['4'] as int,
        five: distribution['5'] as int,
      ),
      updatedAt: updatedAt == null ? null : DateTime.parse(updatedAt),
    );
  }

  static Map<String, dynamic> toJson(PlaceRatingStatistics value) => {
    'averageRating': value.averageRating,
    'ratingCount': value.ratingCount,
    'writtenReviewCount': value.writtenReviewCount,
    'distribution': {
      for (var stars = 1; stars <= 5; stars++)
        '$stars': value.distribution.countFor(stars),
    },
    'updatedAt': value.updatedAt?.toIso8601String(),
  };
}
