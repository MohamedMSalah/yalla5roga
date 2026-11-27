import 'package:dartz/dartz.dart';
import 'package:yalla_5roga/core/error/failures.dart';

import '../entities/effective_starting_location.dart';

abstract interface class StartingLocationRepository {
  Future<Either<Failure, EffectiveStartingLocation>> get(
    String account,
    StartingLocationScope scope,
  );

  Future<Either<Failure, EffectiveStartingLocation>> set(
    String account,
    StartingLocationScope scope,
    StartingLocationOverride override, {
    required String? consentPolicyVersion,
  });

  Future<Either<Failure, EffectiveStartingLocation>> clear(
    String account,
    StartingLocationScope scope,
  );
}
