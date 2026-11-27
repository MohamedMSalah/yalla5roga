class RatingDistribution {
  const RatingDistribution({
    required this.one,
    required this.two,
    required this.three,
    required this.four,
    required this.five,
  });

  final int one, two, three, four, five;

  int countFor(int stars) => switch (stars) {
    1 => one,
    2 => two,
    3 => three,
    4 => four,
    5 => five,
    _ => throw RangeError.range(stars, 1, 5),
  };
}

class PlaceRatingStatistics {
  const PlaceRatingStatistics({
    required this.averageRating,
    required this.ratingCount,
    required this.writtenReviewCount,
    required this.distribution,
    this.updatedAt,
  });

  final double? averageRating;
  final int ratingCount, writtenReviewCount;
  final RatingDistribution distribution;
  final DateTime? updatedAt;

  bool isNewerThan(PlaceRatingStatistics? other) {
    if (other == null) return true;
    final date = updatedAt;
    return date != null &&
        (other.updatedAt == null || date.isAfter(other.updatedAt!));
  }
}
