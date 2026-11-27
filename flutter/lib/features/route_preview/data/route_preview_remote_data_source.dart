import 'package:dio/dio.dart';
import 'package:yalla_5roga/core/constants/api_constants.dart';
import 'package:yalla_5roga/core/network/api_client.dart';
import 'package:yalla_5roga/core/network/dio_interceptors.dart';
import 'package:yalla_5roga/features/starting_location/domain/entities/effective_starting_location.dart';

import '../domain/route_preview_entity.dart';
import 'route_preview_model.dart';

class RoutePreviewRemoteDataSource {
  const RoutePreviewRemoteDataSource(this._api);

  final ApiClient _api;

  Future<RoutePreviewEntity> get(
    String account,
    RoutePreviewTarget target,
  ) async {
    final scope = target.scope;
    final recommendation = target.recommendation;
    final path = switch ((scope.context, recommendation)) {
      (StartingLocationContext.meetup, final row?) =>
        ApiConstants.myMeetupRoute(scope.id, row.placeId),
      (StartingLocationContext.outing, null) => ApiConstants.myOutingRoute(
        scope.id,
      ),
      _ => throw const FormatException('Invalid route preview context'),
    };
    final response = await _api.get<Map<String, dynamic>>(
      path,
      queryParameters: recommendation == null
          ? null
          : {
              'calculation_id': recommendation.calculationId,
              'input_version': recommendation.inputVersion,
            },
      options: Options(extra: {expectedUserIdKey: account}),
      useSnapshots: false,
    );
    final envelope = response.data;
    if (envelope?['success'] != true) {
      throw const FormatException('Invalid route preview response');
    }
    final preview = RoutePreviewModel.fromJson(
      envelope!['data'] as Map<String, dynamic>,
    );
    if (recommendation != null &&
        preview.inputVersion != recommendation.inputVersion) {
      throw const FormatException('Unexpected meetup route preview version');
    }
    return preview;
  }
}
