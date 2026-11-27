import 'package:dartz/dartz.dart';
import 'package:flutter/foundation.dart';
import 'package:yalla_5roga/core/error/failures.dart';

import '../../domain/repositories/location_travel_notification_repository.dart';

class DepartureReminderPreferencesProvider extends ChangeNotifier {
  DepartureReminderPreferencesProvider(
    this._repository,
    this._account,
    this._isCurrent,
  );

  final LocationTravelNotificationRepository _repository;
  final String _account;
  final bool Function() _isCurrent;
  bool _disposed = false;
  bool busy = false;
  DepartureReminderPreferences? value;
  Failure? failure;

  Future<void> load() => _run(() => _repository.preferences(_account));

  Future<void> update({bool? enabled, int? bufferMinutes}) => _run(
    () => _repository.updatePreferences(
      _account,
      enabled: enabled,
      bufferMinutes: bufferMinutes,
    ),
  );

  Future<void> _run(
    Future<Either<Failure, DepartureReminderPreferences>> Function() request,
  ) async {
    if (_disposed || busy || !_isCurrent()) return;
    busy = true;
    failure = null;
    notifyListeners();
    final result = await request();
    if (_disposed || !_isCurrent()) return;
    result.fold(
      (Failure error) => failure = error,
      (DepartureReminderPreferences preferences) => value = preferences,
    );
    busy = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
