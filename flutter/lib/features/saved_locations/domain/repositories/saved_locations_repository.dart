import 'package:dartz/dartz.dart';
import 'package:yalla_5roga/core/error/failures.dart';

import 'package:yalla_5roga/features/transportation/domain/entities/transportation_preference.dart';

import '../entities/default_starting_location.dart';
import '../entities/saved_location.dart';

abstract interface class SavedLocationsRepository {
  Future<Either<Failure, List<SavedLocation>>> list();
  Future<Either<Failure, SavedLocation>> get(String id);
  Future<Either<Failure, SavedLocation>> create(SavedLocationDraft draft);
  Future<Either<Failure, SavedLocation>> update(
    String id,
    SavedLocationDraft draft,
  );
  Future<Either<Failure, Unit>> delete(String id);
  Future<Either<Failure, DefaultStartingLocation?>> getDefault();
  Future<Either<Failure, DefaultStartingLocation>> setDefault(
    StartingLocationSource source,
    String referenceId,
  );
  Future<Either<Failure, Unit>> clearDefault();
  Future<Either<Failure, TransportationMode?>> updateBookmarkTransportation(
    String id,
    TransportationMode? mode,
  );
}
