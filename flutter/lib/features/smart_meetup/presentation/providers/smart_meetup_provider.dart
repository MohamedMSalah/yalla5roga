import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:flutter/foundation.dart';
import 'package:yalla_5roga/core/error/failures.dart';

import '../../domain/entities/meetup_preferences.dart';
import '../../domain/entities/meetup_session.dart';
import '../../domain/entities/smart_meetup_realtime_event.dart';
import '../../domain/entities/standalone_participant.dart';
import '../../domain/repositories/smart_meetup_repository.dart';
import '../../domain/smart_meetup_realtime.dart';
import 'meetup_preferences_provider.dart';
import 'meetup_refresh_debouncer.dart';

class SmartMeetupProvider extends ChangeNotifier {
  SmartMeetupProvider(
    this._repository,
    this.groupId,
    this._account, {
    this.realtime,
  }) : preferences = MeetupPreferencesProvider(_repository, _account);
  SmartMeetupProvider.standalone(
    SmartMeetupRepository repository,
    String? account, {
    SmartMeetupRealtime? realtime,
  }) : this(repository, null, account, realtime: realtime);
  final SmartMeetupRepository _repository;
  final String? groupId;
  final String? _account;
  final SmartMeetupRealtime? realtime;
  final MeetupPreferencesProvider preferences;

  final _refresh = MeetupRefreshDebouncer();
  SmartMeetupRealtimeSubscription? _subscription;
  String? _subscribedId;
  Timer? _expiry;
  int _minimumVersion = 0;
  int _generation = 0;
  bool _active = false;
  bool _needsSnapshot = false;
  MeetupSession? session;
  Failure? failure;
  bool loading = false;
  bool _reloadPending = false;
  bool _closed = false;
  bool _disposed = false;

  bool get snapshotIsCurrent =>
      !_needsSnapshot && (session?.inputVersion ?? 0) >= _minimumVersion;

  void setActive(bool active) {
    if (_closed || _disposed || _active == active) return;
    _active = active;
    if (!active) {
      _stopWatching();
      return;
    }
    if (session?.status == MeetupSessionStatus.active) {
      _needsSnapshot = true;
      _watchSession();
      requestReload();
    }
  }

  void requestReload() {
    if (!_active ||
        _closed ||
        _disposed ||
        (session == null && failure is! NetworkFailure)) {
      return;
    }
    _refresh.schedule(() => unawaited(reload()));
  }

  void _watchSession() {
    final current = session;
    final account = _account;
    if (!_active ||
        account == null ||
        current == null ||
        current.status != MeetupSessionStatus.active) {
      _stopWatching();
      return;
    }
    if (_subscribedId != current.id) {
      _subscription?.dispose();
      _subscribedId = current.id;
      _subscription = realtime?.subscribe(
        account,
        current.id,
        onChange: _onChange,
        onJoined: (version, reconnect) {
          if (!_active || session?.id != current.id) return;
          if (version != null && version > _minimumVersion) {
            _minimumVersion = version;
            _needsSnapshot = true;
            notifyListeners();
            requestReload();
          } else if (reconnect || version == null) {
            requestReload();
          }
        },
      );
    }
    _expiry?.cancel();
    _expiry = Timer(current.expiresAt.difference(DateTime.now()), () {
      _closeSession(MeetupSessionStatus.expired, _minimumVersion);
    });
  }

  void _onChange(SmartMeetupRealtimeEvent change) {
    if (!_active || session?.id != change.sessionId) return;
    final version = change.inputVersion;
    switch (change.change) {
      case SmartMeetupChange.subscriptionRevoked:
        _clearAccess(
          const AuthFailure('Meetup access revoked', 'forbidden', 403),
        );
      case SmartMeetupChange.sessionUpdated:
      case SmartMeetupChange.sessionExpired:
        if (version == null || version < _minimumVersion) return;
        _closeSession(
          change.change == SmartMeetupChange.sessionExpired
              ? MeetupSessionStatus.expired
              : MeetupSessionStatus.cancelled,
          version,
        );
      case SmartMeetupChange.readinessChanged:
      case SmartMeetupChange.preferencesChanged:
        if (version == null || version <= _minimumVersion) return;
        _minimumVersion = version;
        _needsSnapshot = true;
        notifyListeners();
        requestReload();
      case SmartMeetupChange.resultsInvalidated:
      case SmartMeetupChange.calculationCompleted:
        // The readiness snapshot has no result details to replace.
        return;
    }
  }

  void _closeSession(MeetupSessionStatus status, int version) {
    final current = session;
    if (current == null || current.status != MeetupSessionStatus.active) return;
    _generation++;
    _minimumVersion = version;
    session = current.closed(status, version);
    loading = _needsSnapshot = false;
    failure = null;
    _stopWatching();
    notifyListeners();
  }

  void _stopWatching() {
    _subscription?.dispose();
    _subscription = null;
    _subscribedId = null;
    _expiry?.cancel();
    _refresh.cancel();
    _reloadPending = false;
  }

  Future<void> open() {
    final group = groupId;
    return _run(
      (account) => group == null
          ? _repository.openStandalone(account)
          : _repository.open(account, group),
    );
  }

  Future<bool> saveParticipant(
    ManualParticipantDraft draft, {
    String? participantId,
  }) {
    final current = session;
    if (groupId != null || current == null || !current.canManage) {
      return Future.value(false);
    }
    return _run(
      (account) => _repository.saveParticipant(
        account,
        current.id,
        draft,
        participantId: participantId,
      ),
    );
  }

  Future<bool> removeParticipant(String participantId) {
    final current = session;
    if (groupId != null || current == null || !current.canManage) {
      return Future.value(false);
    }
    return _run(
      (account) =>
          _repository.removeParticipant(account, current.id, participantId),
    );
  }

  Future<void> reload() {
    if (loading) {
      _reloadPending = true;
      return Future.value();
    }
    final current = session;
    return current == null
        ? open()
        : _run((account) => _repository.refresh(account, current.id));
  }

  Future<bool> updatePreferences(
    String sessionId,
    MeetupPreferences draft, {
    required bool reset,
  }) async {
    final current = session;
    if (current == null || current.id != sessionId || !current.canManage) {
      return false;
    }
    return _run(
      (account) => reset
          ? _repository.resetPreferences(account, current.id)
          : _repository.update(account, current.id, draft),
    );
  }

  Future<void> cancel() async {
    final current = session;
    if (current == null || !current.canManage) return;
    await _run((account) => _repository.cancel(account, current.id));
  }

  void accountChanged(String? account) {
    if (_closed || account == _account) return;
    _closed = true;
    preferences.close();
    _clearAccess(const AuthFailure());
  }

  void _clearAccess(Failure error) {
    _generation++;
    _stopWatching();
    session = null;
    _minimumVersion = 0;
    loading = _needsSnapshot = false;
    failure = error;
    notifyListeners();
  }

  Future<bool> _run(
    Future<Either<Failure, MeetupSession>> Function(String) request,
  ) async {
    final account = _account;
    if (_disposed || _closed || loading) return false;
    if (account == null) {
      failure = const AuthFailure();
      notifyListeners();
      return false;
    }
    loading = true;
    failure = null;
    final generation = _generation;
    _refresh.cancel();
    notifyListeners();
    final result = await request(account);
    if (_disposed || _closed || generation != _generation) return false;
    loading = false;
    var accepted = false;
    result.fold(
      (error) {
        failure = error;
        if (error is AuthFailure ||
            error.statusCode == 401 ||
            error.statusCode == 403 ||
            error.statusCode == 404) {
          _clearAccess(error);
        }
      },
      (value) {
        if (value.id == session?.id &&
            (value.inputVersion < _minimumVersion ||
                (session?.status != MeetupSessionStatus.active &&
                    value.status == MeetupSessionStatus.active))) {
          return;
        }
        session = value;
        _minimumVersion = value.inputVersion;
        _needsSnapshot = false;
        accepted = true;
        _watchSession();
        if (preferences.categories == null && preferences.failure == null) {
          unawaited(preferences.loadCategories());
        }
      },
    );
    if (generation != _generation) return false;
    notifyListeners();
    if (_reloadPending) {
      _reloadPending = false;
      requestReload();
    }
    return accepted;
  }

  @override
  void dispose() {
    _disposed = true;
    _stopWatching();
    session = null;
    preferences.dispose();
    super.dispose();
  }
}
