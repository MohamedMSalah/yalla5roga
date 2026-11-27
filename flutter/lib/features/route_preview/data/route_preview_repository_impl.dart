import 'package:dartz/dartz.dart';
import 'package:yalla_5roga/core/error/exception_mapper.dart';
import 'package:yalla_5roga/core/error/failures.dart';
import 'package:yalla_5roga/core/network/network_info.dart';

import '../domain/route_preview_entity.dart';
import '../domain/route_preview_repository.dart';
import 'route_preview_remote_data_source.dart';

class RoutePreviewRepositoryImpl implements RoutePreviewRepository {
  const RoutePreviewRepositoryImpl(this._remote, this._network);

  final RoutePreviewRemoteDataSource _remote;
  final NetworkInfo _network;

  @override
  Future<Either<Failure, RoutePreviewEntity>> get(
    String account,
    RoutePreviewTarget target,
  ) async {
    try {
      if (!await _network.isConnected) return const Left(NetworkFailure());
      return Right(await _remote.get(account, target));
    } catch (error) {
      return Left(ExceptionMapper.toFailure(error));
    }
  }
}
