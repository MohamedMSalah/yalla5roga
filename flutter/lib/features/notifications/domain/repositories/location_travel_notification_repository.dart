import 'package:dartz/dartz.dart';
import 'package:yalla_5roga/core/error/failures.dart';
import 'package:yalla_5roga/features/transportation/domain/entities/transportation_preference.dart';

enum LocationRequestStatus { requested, cooldown, unavailable }

class LocationRequestResult {
  const LocationRequestResult(this.status, this.retryAt);

  final LocationRequestStatus status;
  final DateTime? retryAt;
}

class DepartureReminderPreferences {
  const DepartureReminderPreferences(this.enabled, this.bufferMinutes);

  final bool enabled;
  final int bufferMinutes;
}

class DepartureReminder {
  const DepartureReminder({
    required this.preferences,
    required this.status,
    required this.hasLocation,
    required this.locationName,
    required this.arabicLocationName,
    required this.mode,
    required this.journeySeconds,
    required this.departureAt,
  });

  final DepartureReminderPreferences preferences;
  final String status;
  final bool hasLocation;
  final String? locationName;
  final String? arabicLocationName;
  final TransportationMode? mode;
  final int? journeySeconds;
  final DateTime? departureAt;
}

abstract interface class LocationTravelNotificationRepository {
  Future<Either<Failure, LocationRequestResult>> requestLocation(
    String account,
    String sessionId,
    String targetUserId,
  );
  Future<Either<Failure, DepartureReminderPreferences>> preferences(
    String account,
  );
  Future<Either<Failure, DepartureReminderPreferences>> updatePreferences(
    String account, {
    bool? enabled,
    int? bufferMinutes,
  });
  Future<Either<Failure, DepartureReminder>> departureReminder(
    String account,
    String outingId, {
    bool schedule = false,
  });
  Future<Either<Failure, Unit>> clearDepartureReminder(
    String account,
    String outingId,
  );
}
