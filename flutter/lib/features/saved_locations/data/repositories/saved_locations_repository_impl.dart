import 'package:dartz/dartz.dart';
import 'package:yalla_5roga/core/error/exception_mapper.dart';
import 'package:yalla_5roga/core/error/failures.dart';
import 'package:yalla_5roga/core/network/network_info.dart';

import 'package:yalla_5roga/features/transportation/domain/entities/transportation_preference.dart';
import 'package:yalla_5roga/features/transportation/domain/entities/routing_capabilities.dart';
import 'package:yalla_5roga/features/transportation/domain/repositories/transportation_preferences_repository.dart';

import '../../domain/entities/default_starting_location.dart';
import '../../domain/entities/saved_location.dart';
import '../../domain/repositories/saved_locations_repository.dart';
import '../datasources/saved_locations_remote_datasource.dart';

class SavedLocationsRepositoryImpl
    implements SavedLocationsRepository, TransportationPreferencesRepository {
  const SavedLocationsRepositoryImpl(
    this._remote,
    this._network,
    this._currentUserId,
  );

  final SavedLocationsRemoteDataSource _remote;
  final NetworkInfo _network;
  final String? Function() _currentUserId;

  Future<Either<Failure, T>> _request<T>(
    Future<T> Function(String owner) request,
  ) async {
    final owner = _currentUserId();
    if (owner == null) return const Left(AuthFailure());
    try {
      if (!await _network.isConnected) return const Left(NetworkFailure());
      if (_currentUserId() != owner) return const Left(AuthFailure());
      final result = await request(owner);
      if (_currentUserId() != owner) return const Left(AuthFailure());
      return Right(result);
    } catch (error) {
      return Left(ExceptionMapper.toFailure(error));
    }
  }

  @override
  Future<Either<Failure, List<SavedLocation>>> list() => _request(_remote.list);

  @override
  Future<Either<Failure, SavedLocation>> get(String id) =>
      _request((owner) => _remote.get(owner, id));

  @override
  Future<Either<Failure, SavedLocation>> create(SavedLocationDraft draft) =>
      _request((owner) => _remote.create(owner, draft));

  @override
  Future<Either<Failure, SavedLocation>> update(
    String id,
    SavedLocationDraft draft,
  ) => _request((owner) => _remote.update(owner, id, draft));

  @override
  Future<Either<Failure, Unit>> delete(String id) => _request((owner) async {
    await _remote.delete(owner, id);
    return unit;
  });

  @override
  Future<Either<Failure, DefaultStartingLocation?>> getDefault() =>
      _request(_remote.getDefault);

  @override
  Future<Either<Failure, DefaultStartingLocation>> setDefault(
    StartingLocationSource source,
    String referenceId,
  ) => _request((owner) => _remote.setDefault(owner, source, referenceId));

  @override
  Future<Either<Failure, TransportationPreference>>
  getTransportationPreference() =>
      _request(_remote.getTransportationPreference);

  @override
  Future<Either<Failure, TransportationPreference>>
  updateTransportationPreference(TransportationMode? mode) =>
      _request((owner) => _remote.updateTransportationPreference(owner, mode));

  @override
  Future<Either<Failure, List<RoutingCapabilities>>> getRoutingCapabilities() =>
      _request(_remote.getRoutingCapabilities);

  @override
  Future<Either<Failure, TransportationMode?>> updateBookmarkTransportation(
    String id,
    TransportationMode? mode,
  ) => _request(
    (owner) => _remote.updateBookmarkTransportation(owner, id, mode),
  );

  @override
  Future<Either<Failure, Unit>> clearDefault() => _request((owner) async {
    await _remote.clearDefault(owner);
    return unit;
  });
}
