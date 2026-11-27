import 'package:dartz/dartz.dart';
import 'package:yalla_5roga/core/error/exception_mapper.dart';
import 'package:yalla_5roga/core/error/failures.dart';
import 'package:yalla_5roga/core/network/network_info.dart';

import '../../domain/entities/location_privacy_settings.dart';
import '../../domain/repositories/location_privacy_repository.dart';
import '../datasources/location_privacy_remote_datasource.dart';

class LocationPrivacyRepositoryImpl implements LocationPrivacyRepository {
  const LocationPrivacyRepositoryImpl(
    this._remote,
    this._network,
    this._account,
  );

  final LocationPrivacyRemoteDataSource _remote;
  final NetworkInfo _network;
  final String? Function() _account;

  Future<Either<Failure, T>> _request<T>(
    Future<T> Function(String) request,
  ) async {
    final owner = _account();
    if (owner == null) return const Left(AuthFailure());
    try {
      if (!await _network.isConnected) return const Left(NetworkFailure());
      if (_account() != owner) return const Left(AuthFailure());
      final result = await request(owner);
      if (_account() != owner) return const Left(AuthFailure());
      return Right(result);
    } catch (error) {
      return Left(ExceptionMapper.toFailure(error));
    }
  }

  @override
  Future<Either<Failure, LocationPrivacySettings>> getSettings() =>
      _request(_remote.getSettings);

  @override
  Future<Either<Failure, LocationPrivacySettings>> updateVisibility(
    LocationVisibility visibility,
  ) => _request((owner) => _remote.updateVisibility(owner, visibility));

  @override
  Future<Either<Failure, LocationPrivacySettings>> grantConsent(
    String acceptedPolicyVersion,
  ) => _request((owner) => _remote.grantConsent(owner, acceptedPolicyVersion));

  @override
  Future<Either<Failure, LocationPrivacySettings>> withdrawConsent() =>
      _request(_remote.withdrawConsent);

  @override
  Future<Either<Failure, Set<String>>> getExcludedGroups() =>
      _request(_remote.getExcludedGroups);

  @override
  Future<Either<Failure, bool>> setGroupExcluded(
    String groupId,
    bool excluded,
  ) => _request((owner) => _remote.setGroupExcluded(owner, groupId, excluded));
}
