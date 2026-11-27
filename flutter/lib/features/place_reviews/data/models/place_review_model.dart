import '../../domain/entities/place_review.dart';

abstract final class PlaceReviewModel {
  static PlaceReview fromJson(Map<String, dynamic> json) => PlaceReview(
    id: json['id'] as String,
    placeId: json['placeId'] as String,
    rating: json['rating'] as int,
    text: json['reviewText'] as String?,
    reviewerName: (json['reviewer'] as Map<String, dynamic>)['name'] as String,
    createdAt: DateTime.parse(json['createdAt'] as String),
    updatedAt: DateTime.parse(json['updatedAt'] as String),
    isMine: json['isMine'] as bool,
    hidden: json['moderationStatus'] == 'hidden',
  );
}
