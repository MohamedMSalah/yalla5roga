import 'package:dartz/dartz.dart';
import 'package:yalla_5roga/core/error/failures.dart';

import '../entities/routing_capabilities.dart';
import '../entities/transportation_preference.dart';

abstract interface class TransportationPreferencesRepository {
  Future<Either<Failure, TransportationPreference>>
  getTransportationPreference();
  Future<Either<Failure, TransportationPreference>>
  updateTransportationPreference(TransportationMode? mode);
  Future<Either<Failure, List<RoutingCapabilities>>> getRoutingCapabilities();
}
