import 'package:dartz/dartz.dart';
import 'package:yalla_5roga/core/error/failures.dart';

abstract interface class NotificationPreferencesRepository {
  Future<Either<Failure, Map<String, bool>>> updatePreferences(
    Map<String, bool> patch,
  );
}
