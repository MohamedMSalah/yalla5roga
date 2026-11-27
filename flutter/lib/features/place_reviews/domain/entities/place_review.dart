import 'place_rating_statistics.dart';

enum ReviewReportReason { spam, harassment, inappropriate, offTopic, other }

class PlaceReview {
  const PlaceReview({
    required this.id,
    required this.placeId,
    required this.rating,
    required this.reviewerName,
    required this.createdAt,
    required this.updatedAt,
    required this.isMine,
    this.text,
    this.hidden = false,
  });

  final String id, placeId, reviewerName;
  final int rating;
  final DateTime createdAt, updatedAt;
  final String? text;
  final bool isMine, hidden;
}

class ReviewPage<T> {
  const ReviewPage(this.items, this.nextCursor);

  final List<T> items;
  final String? nextCursor;
}

class PlaceReviewMutation {
  const PlaceReviewMutation(this.review, this.statistics);

  final PlaceReview? review;
  final PlaceRatingStatistics statistics;
}

class BlockedReviewAuthor {
  const BlockedReviewAuthor(this.id, this.name);

  final String id, name;
}
