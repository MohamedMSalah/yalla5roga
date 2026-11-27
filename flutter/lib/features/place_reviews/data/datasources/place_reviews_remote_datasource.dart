import 'package:dio/dio.dart';
import 'package:yalla_5roga/core/constants/api_constants.dart';
import 'package:yalla_5roga/core/network/api_client.dart';
import 'package:yalla_5roga/core/network/dio_interceptors.dart';

import '../../domain/entities/place_rating_statistics.dart';
import '../../domain/entities/place_review.dart';
import '../models/place_rating_statistics_model.dart';
import '../models/place_review_model.dart';

class PlaceReviewsRemoteDataSource {
  const PlaceReviewsRemoteDataSource(this._api);

  final ApiClient _api;

  Options _bound(String owner) => Options(extra: {expectedUserIdKey: owner});

  Object? _payload(Response<Map<String, dynamic>> response) {
    final json = response.data;
    if (json == null || json['success'] != true || !json.containsKey('data')) {
      throw const FormatException('Invalid place reviews response');
    }
    return json['data'];
  }

  Future<Object?> _read(String path, String owner, {String? cursor}) async =>
      _payload(
        await _api.get<Map<String, dynamic>>(
          path,
          queryParameters: {'cursor': ?cursor},
          options: _bound(owner),
          useSnapshots: false,
        ),
      );

  ReviewPage<T> _page<T>(Object? data, T Function(Map<String, dynamic>) parse) {
    final json = data as Map<String, dynamic>;
    return ReviewPage(
      List.unmodifiable(
        (json['items'] as List).cast<Map<String, dynamic>>().map(parse),
      ),
      json['nextCursor'] as String?,
    );
  }

  PlaceReview? _review(Object? data) => data == null
      ? null
      : PlaceReviewModel.fromJson(data as Map<String, dynamic>);

  PlaceReviewMutation _mutation(Response<Map<String, dynamic>> response) {
    final json = _payload(response) as Map<String, dynamic>;
    return PlaceReviewMutation(
      _review(json['review']),
      PlaceRatingStatisticsModel.fromJson(
        json['statistics'] as Map<String, dynamic>,
      ),
    );
  }

  Future<PlaceRatingStatistics> statistics(String id) async =>
      PlaceRatingStatisticsModel.fromJson(
        _payload(
          await _api.get<Map<String, dynamic>>(
            ApiConstants.placeRatings(id),
            publicRead: true,
          ),
        ) as Map<String, dynamic>,
      );

  Future<PlaceReview?> mine(String owner, String id) async =>
      _review(await _read(ApiConstants.myPlaceRating(id), owner));

  Future<ReviewPage<PlaceReview>> reviews(
    String owner,
    String id,
    String? cursor,
  ) async => _page(
    await _read(ApiConstants.placeReviews(id), owner, cursor: cursor),
    PlaceReviewModel.fromJson,
  );

  Future<PlaceReviewMutation> save(
    String owner,
    String id,
    int rating,
    String? text, {
    required bool editing,
  }) async {
    final path = ApiConstants.myPlaceRating(id);
    final data = {'rating': rating, 'reviewText': text};
    final options = _bound(owner);
    final response = editing
        ? await _api.patch<Map<String, dynamic>>(
            path,
            data: data,
            options: options,
          )
        : await _api.put<Map<String, dynamic>>(
            path,
            data: data,
            options: options,
          );
    return _mutation(response);
  }

  Future<PlaceReviewMutation> remove(String owner, String id) async =>
      _mutation(
        await _api.delete<Map<String, dynamic>>(
          ApiConstants.myPlaceRating(id),
          options: _bound(owner),
        ),
      );

  Future<void> report(
    String owner,
    PlaceReview review,
    ReviewReportReason reason,
  ) async {
    await _api.post(
      '${ApiConstants.placeReview(review.placeId, review.id)}/report',
      data: {
        'reason': reason == ReviewReportReason.offTopic
            ? 'off_topic'
            : reason.name,
      },
      options: _bound(owner),
    );
  }

  Future<void> block(String owner, PlaceReview review) async {
    await _api.put(
      '${ApiConstants.placeReview(review.placeId, review.id)}/block',
      options: _bound(owner),
    );
  }

  Future<ReviewPage<BlockedReviewAuthor>> blocked(
    String owner,
    String? cursor,
  ) async => _page(
    await _read(ApiConstants.placeReviewBlocks, owner, cursor: cursor),
    (row) => BlockedReviewAuthor(row['id'] as String, row['name'] as String),
  );

  Future<void> unblock(String owner, String id) async {
    await _api.delete(
      '${ApiConstants.placeReviewBlocks}/$id',
      options: _bound(owner),
    );
  }
}
