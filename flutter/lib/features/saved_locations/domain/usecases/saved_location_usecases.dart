import 'package:dartz/dartz.dart';
import 'package:yalla_5roga/core/error/failures.dart';

import 'package:yalla_5roga/features/transportation/domain/entities/transportation_preference.dart';

import '../entities/default_starting_location.dart';
import '../entities/saved_location.dart';
import '../repositories/saved_locations_repository.dart';

class SavedLocationUseCases {
  const SavedLocationUseCases(this._repository);

  final SavedLocationsRepository _repository;

  Future<Either<Failure, List<SavedLocation>>> list() => _repository.list();

  Future<Either<Failure, SavedLocation>> get(String id) => _repository.get(id);

  Future<Either<Failure, SavedLocation>> save(
    SavedLocationDraft draft, {
    String? id,
  }) async {
    if (!draft.isValid) return const Left(ValidationFailure());
    return id == null
        ? _repository.create(draft)
        : _repository.update(id, draft);
  }

  Future<Either<Failure, Unit>> delete(String id) => _repository.delete(id);

  Future<Either<Failure, DefaultStartingLocation?>> getDefault() =>
      _repository.getDefault();

  Future<Either<Failure, DefaultStartingLocation>> setDefault(
    StartingLocationSource source,
    String referenceId,
  ) => _repository.setDefault(source, referenceId);

  Future<Either<Failure, TransportationMode?>> updateBookmarkTransportation(
    String id,
    TransportationMode? mode,
  ) => _repository.updateBookmarkTransportation(id, mode);

  Future<Either<Failure, Unit>> clearDefault() => _repository.clearDefault();
}
