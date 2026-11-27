import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:flutter/foundation.dart';
import 'package:yalla_5roga/core/error/failures.dart';

import '../../domain/entities/meetup_results.dart';
import '../../domain/entities/meetup_session.dart';
import '../../domain/entities/smart_meetup_realtime_event.dart';
import '../../domain/repositories/smart_meetup_repository.dart';
import '../../domain/smart_meetup_realtime.dart';
import 'meetup_refresh_debouncer.dart';

class MeetupResultsProvider extends ChangeNotifier {
  MeetupResultsProvider(
    this._repository,
    this.sessionId,
    this._account,
    this._minimumVersion, {
    this.realtime,
    this.sessionExpiresAt,
  });

  final SmartMeetupRepository _repository;
  final String sessionId;
  final String? _account;
  final SmartMeetupRealtime? realtime;
  final DateTime? sessionExpiresAt;
  final _refresh = MeetupRefreshDebouncer();
  SmartMeetupRealtimeSubscription? _subscription;
  int _minimumVersion;
  int _minimumAttempt = 0;
  int _invalidatedAttempt = 0;
  int _completedAttempt = 0;
  int _responseRevision = 0;
  bool _active = false;
  bool _hasRequested = false;
  bool _reconciling = false;
  bool _reloadPending = false;
  bool _stale = false;
  bool _accessLost = false;
  MeetupSessionStatus sessionStatus = MeetupSessionStatus.active;
  MeetupResults? result;
  Failure? failure;
  bool loading = false;
  bool offline = false;
  bool _closed = false;
  int _generation = 0;
  Timer? _expiry;

  bool get hasExpired {
    final expiresAt = result?.calculation?.expiresAt;
    return expiresAt != null && !expiresAt.isAfter(DateTime.now());
  }

  bool get isStale =>
      _stale ||
      hasExpired ||
      result?.status == MeetupCalculationStatus.stale ||
      (result?.hasPublishedRecommendations == true && !result!.canConsume);

  bool get canConsume =>
      sessionStatus == MeetupSessionStatus.active &&
      !offline &&
      !loading &&
      !_reconciling &&
      !isStale &&
      failure == null &&
      (result?.canConsume ?? false);

  void setActive(bool active) {
    if (_closed || _active == active) return;
    _active = active;
    if (!active) {
      _stopWatching();
      return;
    }
    if (_accessLost || sessionStatus != MeetupSessionStatus.active) return;
    _reconciling = _hasRequested;
    final account = _account;
    if (account != null) {
      _subscription = realtime?.subscribe(
        account,
        sessionId,
        onChange: _onChange,
        onJoined: (version, reconnect) {
          if (!_active) return;
          if (version != null && version > _minimumVersion) {
            _advanceVersion(version);
            _invalidate();
          } else if (version != null || reconnect || _hasRequested) {
            if (reconnect) {
              _reconciling = true;
              notifyListeners();
            }
            requestReload();
          }
        },
      );
    }
    _scheduleExpiry();
    if (_hasRequested) requestReload();
  }

  void requestReload() {
    if (!_active ||
        _closed ||
        _accessLost ||
        offline ||
        sessionStatus != MeetupSessionStatus.active) {
      return;
    }
    _refresh.schedule(() {
      if (loading) {
        _reloadPending = true;
      } else {
        unawaited(load());
      }
    });
  }

  void _advanceVersion(int version) {
    _minimumVersion = version;
    _minimumAttempt = _invalidatedAttempt = _completedAttempt = 0;
  }

  int _attemptFor(MeetupResults? value) {
    final calculation = value?.calculation;
    return calculation?.inputVersion == _minimumVersion
        ? calculation!.attempt
        : 0;
  }

  void _invalidate({bool stale = true}) {
    _responseRevision++;
    _stale |= stale && result != null;
    notifyListeners();
    requestReload();
  }

  void _onChange(SmartMeetupRealtimeEvent event) {
    if (!_active || event.sessionId != sessionId) return;
    if (event.change == SmartMeetupChange.subscriptionRevoked) {
      _clearAccess(
        const AuthFailure('Meetup access revoked', 'forbidden', 403),
      );
      return;
    }
    final version = event.inputVersion;
    if (version == null || version < _minimumVersion) return;
    final newerInputs = version > _minimumVersion;
    if (newerInputs) _advanceVersion(version);
    switch (event.change) {
      case SmartMeetupChange.sessionExpired:
      case SmartMeetupChange.sessionUpdated:
        _closeSession(
          event.change == SmartMeetupChange.sessionExpired
              ? MeetupSessionStatus.expired
              : MeetupSessionStatus.cancelled,
        );
      case SmartMeetupChange.readinessChanged:
      case SmartMeetupChange.preferencesChanged:
        if (newerInputs) _invalidate();
      case SmartMeetupChange.resultsInvalidated:
        final attempt = event.calculationAttempt!;
        if (attempt < _minimumAttempt || attempt <= _invalidatedAttempt) return;
        _minimumAttempt = _invalidatedAttempt = attempt;
        if (newerInputs ||
            _attemptFor(result) != attempt ||
            result?.status != MeetupCalculationStatus.stale) {
          _invalidate();
        }
      case SmartMeetupChange.calculationCompleted:
        final attempt = event.calculationAttempt!;
        if (attempt < _minimumAttempt ||
            attempt <= _invalidatedAttempt ||
            attempt <= _completedAttempt) {
          return;
        }
        _completedAttempt = _minimumAttempt = attempt;
        if (_attemptFor(result) == attempt &&
            const {
              MeetupCalculationStatus.ready,
              MeetupCalculationStatus.partial,
              MeetupCalculationStatus.noMatchingVenues,
              MeetupCalculationStatus.failed,
            }.contains(result?.status)) {
          return;
        }
        _invalidate(stale: newerInputs || _attemptFor(result) != attempt);
      case SmartMeetupChange.subscriptionRevoked:
        return;
    }
  }

  void _closeSession(MeetupSessionStatus status) {
    sessionStatus = status;
    _generation++;
    _stopWatching();
    loading = _stale = false;
    result = null;
    failure = null;
    notifyListeners();
  }

  void _stopWatching() {
    _subscription?.dispose();
    _subscription = null;
    _expiry?.cancel();
    _refresh.cancel();
    _reloadPending = false;
  }

  void _scheduleExpiry() {
    _expiry?.cancel();
    if (!_active || sessionStatus != MeetupSessionStatus.active) return;
    final now = DateTime.now();
    final calculationExpiry = result?.calculation?.expiresAt;
    final sessionExpiry = sessionExpiresAt;
    final deadlines = [
      if (calculationExpiry != null && calculationExpiry.isAfter(now))
        calculationExpiry,
      ?sessionExpiry,
    ]..sort();
    if (deadlines.isEmpty) return;
    _expiry = Timer(deadlines.first.difference(now), () {
      if (sessionExpiry != null && !sessionExpiry.isAfter(DateTime.now())) {
        _closeSession(MeetupSessionStatus.expired);
      } else {
        notifyListeners();
        _scheduleExpiry();
      }
    });
  }

  Future<void> load() async {
    await _run((account) => _repository.results(account, sessionId));
  }

  Future<void> refresh() async {
    await _run((account) => _repository.calculate(account, sessionId));
  }

  Future<List<MeetupRecommendation>?> validate(Set<String> placeIds) async {
    if (!canConsume || placeIds.isEmpty) return null;
    final snapshot = result!;
    final calculationId = snapshot.calculation!.id;
    final checked = await _run(
      (account) =>
          _repository.results(account, sessionId, calculationId: calculationId),
    );
    if (checked == null ||
        !canConsume ||
        checked.calculation?.id != calculationId ||
        checked.inputVersion != snapshot.inputVersion) {
      return null;
    }
    final selected = checked.recommendations
        .where((row) => placeIds.contains(row.place.id))
        .toList(growable: false);
    return selected.length == placeIds.length ? selected : null;
  }

  void setOffline(bool value) {
    if (_closed || offline == value) return;
    offline = value;
    if (offline) {
      _generation++;
      _refresh.cancel();
      _reloadPending = false;
      loading = false;
      failure = const NetworkFailure();
    } else if (_hasRequested) {
      requestReload();
    }
    notifyListeners();
  }

  void accountChanged(String? account) {
    if (_closed || account == _account) return;
    _closed = true;
    _clearAccess(const AuthFailure());
  }

  void _clearAccess(Failure error) {
    _accessLost = true;
    _generation++;
    _stopWatching();
    result = null;
    loading = _stale = false;
    failure = error;
    notifyListeners();
  }

  Future<MeetupResults?> _run(
    Future<Either<Failure, MeetupResults>> Function(String) request,
  ) async {
    _hasRequested = true;
    if (_closed ||
        _accessLost ||
        offline ||
        sessionStatus != MeetupSessionStatus.active) {
      return null;
    }
    final account = _account;
    if (account == null) {
      failure = const AuthFailure();
      notifyListeners();
      return null;
    }
    final generation = ++_generation;
    final revision = _responseRevision;
    _refresh.cancel();
    loading = true;
    failure = null;
    notifyListeners();
    final response = await request(account);
    if (_closed || _generation != generation) return null;
    loading = false;
    final next = response.fold<MeetupResults?>(
      (error) {
        failure = error;
        if (error is AuthFailure ||
            const [401, 403, 404].contains(error.statusCode)) {
          _clearAccess(error);
        }
        return null;
      },
      (value) {
        if (value.inputVersion < _minimumVersion ||
            revision != _responseRevision) {
          return null;
        }
        if (value.sessionStatus != MeetupSessionStatus.active) {
          _closeSession(value.sessionStatus);
          return null;
        }
        if (value.inputVersion > _minimumVersion) {
          _advanceVersion(value.inputVersion);
        }
        final attempt = _attemptFor(value);
        if (attempt < _minimumAttempt ||
            (attempt > 0 &&
                attempt <= _invalidatedAttempt &&
                value.status != MeetupCalculationStatus.stale)) {
          return null;
        }
        _minimumAttempt = attempt;
        if (value.status == MeetupCalculationStatus.stale) {
          _invalidatedAttempt = attempt;
        }
        _stale = false;
        _reconciling = false;
        result = value;
        return value;
      },
    );
    if (_generation != generation) return null;
    _scheduleExpiry();
    notifyListeners();
    if (_reloadPending) {
      _reloadPending = false;
      requestReload();
    }
    return next;
  }

  @override
  void dispose() {
    _closed = true;
    _stopWatching();
    result = null;
    super.dispose();
  }
}
