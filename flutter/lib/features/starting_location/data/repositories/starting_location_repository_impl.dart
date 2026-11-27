import 'package:dartz/dartz.dart';
import 'package:yalla_5roga/core/error/exception_mapper.dart';
import 'package:yalla_5roga/core/error/failures.dart';
import 'package:yalla_5roga/core/network/network_info.dart';

import '../../domain/entities/effective_starting_location.dart';
import '../../domain/repositories/starting_location_repository.dart';
import '../datasources/starting_location_remote_datasource.dart';

class StartingLocationRepositoryImpl implements StartingLocationRepository {
  const StartingLocationRepositoryImpl(this._remote, this._network);

  final StartingLocationRemoteDataSource _remote;
  final NetworkInfo _network;

  Future<Either<Failure, EffectiveStartingLocation>> _request(
    Future<EffectiveStartingLocation> Function() run,
  ) async {
    try {
      if (!await _network.isConnected) return const Left(NetworkFailure());
      return Right(await run());
    } catch (error) {
      return Left(ExceptionMapper.toFailure(error));
    }
  }

  @override
  Future<Either<Failure, EffectiveStartingLocation>> get(
    String account,
    StartingLocationScope scope,
  ) => _request(() => _remote.get(account, scope));

  @override
  Future<Either<Failure, EffectiveStartingLocation>> clear(
    String account,
    StartingLocationScope scope,
  ) => _request(() => _remote.clear(account, scope));

  @override
  Future<Either<Failure, EffectiveStartingLocation>> set(
    String account,
    StartingLocationScope scope,
    StartingLocationOverride override, {
    required String? consentPolicyVersion,
  }) => _request(
    () => _remote.set(account, scope, override, consentPolicyVersion),
  );
}
