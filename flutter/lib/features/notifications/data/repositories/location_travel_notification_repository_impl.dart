import 'package:dartz/dartz.dart';
import 'package:yalla_5roga/core/error/exception_mapper.dart';
import 'package:yalla_5roga/core/error/failures.dart';
import 'package:yalla_5roga/core/network/network_info.dart';
import 'package:yalla_5roga/features/transportation/data/models/transportation_preference_model.dart';

import '../../domain/repositories/location_travel_notification_repository.dart';
import '../datasources/location_travel_notification_remote_datasource.dart';

class LocationTravelNotificationRepositoryImpl
    implements LocationTravelNotificationRepository {
  const LocationTravelNotificationRepositoryImpl(this._remote, this._network);
  final LocationTravelNotificationRemoteDataSource _remote;
  final NetworkInfo _network;

  Future<Either<Failure, T>> _request<T>(Future<T> Function() run) async {
    try {
      if (!await _network.isConnected) return const Left(NetworkFailure());
      return Right(await run());
    } catch (error) {
      return Left(ExceptionMapper.toFailure(error));
    }
  }

  @override
  Future<Either<Failure, LocationRequestResult>> requestLocation(
    String account,
    String sessionId,
    String targetUserId,
  ) => _request(() async {
    final data = await _remote.requestLocation(
      account,
      sessionId,
      targetUserId,
    );
    final status = switch (data['status']) {
      'REQUESTED' => LocationRequestStatus.requested,
      'COOLDOWN' => LocationRequestStatus.cooldown,
      _ => LocationRequestStatus.unavailable,
    };
    return LocationRequestResult(status, _time(data['retry_at']));
  });

  @override
  Future<Either<Failure, DepartureReminderPreferences>> preferences(
    String account,
  ) => _request(() async => _preferences(await _remote.preferences(account)));

  @override
  Future<Either<Failure, DepartureReminderPreferences>> updatePreferences(
    String account, {
    bool? enabled,
    int? bufferMinutes,
  }) => _request(
    () async => _preferences(
      await _remote.updatePreferences(
        account,
        enabled: enabled,
        bufferMinutes: bufferMinutes,
      ),
    ),
  );

  @override
  Future<Either<Failure, DepartureReminder>> departureReminder(
    String account,
    String outingId, {
    bool schedule = false,
  }) => _request(() async {
    final data = await _remote.departureReminder(account, outingId, schedule);
    final location = data['starting_location'] as Map<String, dynamic>?;
    return DepartureReminder(
      preferences: _preferences(data),
      status: data['status'] as String,
      hasLocation: location != null,
      locationName: location?['name'] as String?,
      arabicLocationName: location?['name_ar'] as String?,
      mode: TransportationPreferenceModel.modeFromJson(
        data['transportation_mode'],
      ),
      journeySeconds: data['estimated_journey_seconds'] as int?,
      departureAt: _time(data['suggested_departure_at']),
    );
  });

  @override
  Future<Either<Failure, Unit>> clearDepartureReminder(
    String account,
    String outingId,
  ) => _request(() async {
    await _remote.clearDepartureReminder(account, outingId);
    return unit;
  });

  DepartureReminderPreferences _preferences(Map<String, dynamic> data) =>
      DepartureReminderPreferences(
        data['enabled'] as bool,
        data['preparation_buffer_minutes'] as int,
      );

  DateTime? _time(Object? value) =>
      value is String ? DateTime.tryParse(value) : null;
}
