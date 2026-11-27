import 'package:dartz/dartz.dart' show Either, Unit;
import 'package:flutter/foundation.dart';
import 'package:yalla_5roga/core/error/failures.dart';

import '../../domain/entities/place_rating_statistics.dart';
import '../../domain/entities/place_review.dart';
import '../../domain/repositories/place_reviews_repository.dart';
import 'place_rating_updates.dart';

class PlaceReviewsProvider extends ChangeNotifier {
  PlaceReviewsProvider(
    this._repository,
    this._updates, {
    required this.placeId,
  });

  final String placeId;
  final PlaceReviewsRepository _repository;
  final PlaceRatingUpdates _updates;

  PlaceRatingStatistics? statistics;
  PlaceReview? mine;
  final reviews = <PlaceReview>[];
  final blockedAuthors = <BlockedReviewAuthor>[];
  Failure? ratingFailure, reviewsFailure, blocksFailure;
  bool loading = true,
      loadingPage = false,
      mutating = false,
      loadingBlocks = false;
  String? _cursor, _blocksCursor;
  bool get hasMore => _cursor != null;
  bool get hasMoreBlocks => _blocksCursor != null;
  bool _disposed = false;
  int _pageGeneration = 0;

  Future<void> load() async {
    if (_disposed || mutating) return;
    final generation = ++_pageGeneration;
    loading = true;
    loadingPage = false;
    ratingFailure = null;
    reviewsFailure = null;
    notifyListeners();

    final stats = _repository.statistics(placeId);
    final own = _repository.mine(placeId);
    final written = _repository.reviews(placeId);
    final currentStats = await stats;
    final currentOwn = await own;
    final currentReviews = await written;
    if (_disposed || generation != _pageGeneration) return;

    currentStats.fold((failure) => ratingFailure = failure, (value) {
      statistics = value;
      _updates.accept(placeId, value);
    });
    currentOwn.fold(
      (failure) => ratingFailure = failure,
      (value) => mine = value,
    );
    _applyReviews(currentReviews, replace: true);
    loading = false;
    notifyListeners();
  }

  Future<void> loadMore() async {
    final cursor = _cursor;
    if (cursor == null || loadingPage || loading || mutating) return;
    final generation = _pageGeneration;
    loadingPage = true;
    reviewsFailure = null;
    notifyListeners();
    final result = await _repository.reviews(placeId, cursor: cursor);
    if (_disposed || generation != _pageGeneration) return;
    loadingPage = false;
    _applyReviews(result);
    notifyListeners();
  }

  void _applyReviews(
    Either<Failure, ReviewPage<PlaceReview>> result, {
    bool replace = false,
  }) {
    result.fold((failure) => reviewsFailure = failure, (page) {
      if (replace) reviews.clear();
      final seen = reviews.map((review) => review.id).toSet();
      reviews.addAll(page.items.where((review) => seen.add(review.id)));
      _cursor = page.nextCursor;
    });
  }

  Future<Failure?> save(int rating, String? text) => _mutate(
    () => _repository.save(placeId, rating, text, editing: mine != null),
  );

  Future<Failure?> remove() => _mutate(() => _repository.remove(placeId));

  Future<Failure?> _mutate(
    Future<Either<Failure, PlaceReviewMutation>> Function() request,
  ) async {
    if (_disposed || mutating || loading) return const ServerFailure();
    mutating = true;
    ++_pageGeneration;
    loadingPage = false;
    notifyListeners();
    final response = await request();
    if (_disposed) {
      return response.fold((failure) => failure, (value) {
        _updates.changed(placeId, value.statistics);
        return null;
      });
    }
    final failure = await response.fold<Future<Failure?>>(
      (failure) async => failure,
      (value) async {
        statistics = value.statistics;
        mine = value.review;
        _updates.changed(placeId, value.statistics);
        // Clear the old first page while the edited or deleted entry is replaced.
        reviews.clear();
        _cursor = null;
        await _refreshReviews();
        return null;
      },
    );
    if (!_disposed) {
      mutating = false;
      notifyListeners();
    }
    return failure;
  }

  Future<void> _refreshReviews() async {
    final result = await _repository.reviews(placeId);
    if (_disposed) return;
    reviewsFailure = null;
    _applyReviews(result, replace: true);
  }

  Future<Failure?> report(PlaceReview review, ReviewReportReason reason) async {
    if (_disposed) return const AuthFailure();
    return (await _repository.report(
      review,
      reason,
    )).fold((failure) => failure, (_) => null);
  }

  Future<Failure?> block(PlaceReview review) =>
      _changeBlocks(() => _repository.block(review));

  Future<Failure?> unblock(String id) =>
      _changeBlocks(() => _repository.unblock(id));

  Future<Failure?> _changeBlocks(
    Future<Either<Failure, Unit>> Function() change,
  ) async {
    if (_disposed || mutating || loading) return const ServerFailure();
    mutating = true;
    ++_pageGeneration;
    loadingPage = false;
    notifyListeners();
    final result = await change();
    if (_disposed) return result.fold((failure) => failure, (_) => null);
    final failure = await result.fold<Future<Failure?>>(
      (failure) async => failure,
      (_) async {
        reviews.clear();
        _cursor = null;
        await Future.wait([_refreshReviews(), loadBlocks()]);
        return null;
      },
    );
    if (!_disposed) {
      mutating = false;
      notifyListeners();
    }
    return failure;
  }

  Future<void> loadBlocks({bool more = false}) async {
    if (_disposed || loadingBlocks || (more && _blocksCursor == null)) return;
    loadingBlocks = true;
    blocksFailure = null;
    notifyListeners();
    final result = await _repository.blocked(
      cursor: more ? _blocksCursor : null,
    );
    if (_disposed) return;
    result.fold((failure) => blocksFailure = failure, (page) {
      if (!more) blockedAuthors.clear();
      blockedAuthors.addAll(page.items);
      _blocksCursor = page.nextCursor;
    });
    loadingBlocks = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
