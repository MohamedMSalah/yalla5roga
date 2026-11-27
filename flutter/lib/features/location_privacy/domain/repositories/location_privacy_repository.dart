import 'package:dartz/dartz.dart';
import 'package:yalla_5roga/core/error/failures.dart';

import '../entities/location_privacy_settings.dart';

abstract interface class LocationPrivacyRepository {
  Future<Either<Failure, LocationPrivacySettings>> getSettings();
  Future<Either<Failure, LocationPrivacySettings>> updateVisibility(
    LocationVisibility visibility,
  );
  Future<Either<Failure, LocationPrivacySettings>> grantConsent(
    String acceptedPolicyVersion,
  );
  Future<Either<Failure, LocationPrivacySettings>> withdrawConsent();
  Future<Either<Failure, Set<String>>> getExcludedGroups();
  Future<Either<Failure, bool>> setGroupExcluded(String groupId, bool excluded);
}
