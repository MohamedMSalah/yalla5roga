import 'package:dartz/dartz.dart';
import 'package:yalla_5roga/core/error/exception_mapper.dart';
import 'package:yalla_5roga/core/error/failures.dart';

import '../../domain/entities/place_rating_statistics.dart';
import '../../domain/entities/place_review.dart';
import '../../domain/repositories/place_reviews_repository.dart';
import '../datasources/place_reviews_remote_datasource.dart';

class PlaceReviewsRepositoryImpl implements PlaceReviewsRepository {
  const PlaceReviewsRepositoryImpl(this._remote, this._currentUser);

  final PlaceReviewsRemoteDataSource _remote;
  final String? Function() _currentUser;

  Future<Either<Failure, T>> _request<T>(Future<T> Function() request) async {
    try {
      return Right(await request());
    } catch (error) {
      return Left(ExceptionMapper.toFailure(error));
    }
  }

  Future<Either<Failure, T>> _authenticated<T>(
    Future<T> Function(String) request,
  ) async {
    final owner = _currentUser();
    if (owner == null) return const Left(AuthFailure());
    final result = await _request(() => request(owner));
    return _currentUser() == owner ? result : const Left(AuthFailure());
  }

  @override
  Future<Either<Failure, PlaceRatingStatistics>> statistics(String placeId) =>
      _request(() => _remote.statistics(placeId));

  @override
  Future<Either<Failure, PlaceReview?>> mine(String placeId) =>
      _authenticated((owner) => _remote.mine(owner, placeId));

  @override
  Future<Either<Failure, ReviewPage<PlaceReview>>> reviews(
    String placeId, {
    String? cursor,
  }) => _authenticated((owner) => _remote.reviews(owner, placeId, cursor));

  @override
  Future<Either<Failure, PlaceReviewMutation>> save(
    String placeId,
    int rating,
    String? text, {
    required bool editing,
  }) => _authenticated(
    (owner) => _remote.save(owner, placeId, rating, text, editing: editing),
  );

  @override
  Future<Either<Failure, PlaceReviewMutation>> remove(String placeId) =>
      _authenticated((owner) => _remote.remove(owner, placeId));

  @override
  Future<Either<Failure, Unit>> report(
    PlaceReview review,
    ReviewReportReason reason,
  ) => _authenticated((owner) async {
    await _remote.report(owner, review, reason);
    return unit;
  });

  @override
  Future<Either<Failure, Unit>> block(PlaceReview review) =>
      _authenticated((owner) async {
        await _remote.block(owner, review);
        return unit;
      });

  @override
  Future<Either<Failure, ReviewPage<BlockedReviewAuthor>>> blocked({
    String? cursor,
  }) => _authenticated((owner) => _remote.blocked(owner, cursor));

  @override
  Future<Either<Failure, Unit>> unblock(String id) =>
      _authenticated((owner) async {
        await _remote.unblock(owner, id);
        return unit;
      });
}
