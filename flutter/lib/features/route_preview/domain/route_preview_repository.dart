import 'package:dartz/dartz.dart';
import 'package:yalla_5roga/core/error/failures.dart';

import 'route_preview_entity.dart';

abstract interface class RoutePreviewRepository {
  Future<Either<Failure, RoutePreviewEntity>> get(
    String account,
    RoutePreviewTarget target,
  );
}
