import 'package:dartz/dartz.dart';
import 'package:yalla_5roga/core/error/failures.dart';

import '../entities/place_rating_statistics.dart';
import '../entities/place_review.dart';

abstract interface class PlaceReviewsRepository {
  Future<Either<Failure, PlaceRatingStatistics>> statistics(String placeId);
  Future<Either<Failure, PlaceReview?>> mine(String placeId);
  Future<Either<Failure, ReviewPage<PlaceReview>>> reviews(
    String placeId, {
    String? cursor,
  });
  Future<Either<Failure, PlaceReviewMutation>> save(
    String placeId,
    int rating,
    String? text, {
    required bool editing,
  });
  Future<Either<Failure, PlaceReviewMutation>> remove(String placeId);
  Future<Either<Failure, Unit>> report(
    PlaceReview review,
    ReviewReportReason reason,
  );
  Future<Either<Failure, Unit>> block(PlaceReview review);
  Future<Either<Failure, ReviewPage<BlockedReviewAuthor>>> blocked({
    String? cursor,
  });
  Future<Either<Failure, Unit>> unblock(String id);
}
