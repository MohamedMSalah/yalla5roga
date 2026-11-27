import 'dart:async';

import 'package:yalla_5roga/features/chat/data/datasources/outing_chat_socket_client.dart';

import '../../domain/entities/smart_meetup_realtime_event.dart';
import '../../domain/smart_meetup_realtime.dart';

class SocketSmartMeetupRealtime implements SmartMeetupRealtime {
  SocketSmartMeetupRealtime(this._socket, this._currentAccount);

  final OutingChatSocketClient _socket;
  final String? Function() _currentAccount;
  final _rooms = <(String, String), _MeetupRoom>{};

  @override
  SmartMeetupRealtimeSubscription subscribe(
    String account,
    String sessionId, {
    required void Function(SmartMeetupRealtimeEvent) onChange,
    required void Function(int? version, bool reconnect) onJoined,
  }) {
    final key = (account, sessionId);
    final room = _rooms.putIfAbsent(
      key,
      () => _MeetupRoom(
        _socket,
        sessionId,
        () => _currentAccount() == account,
        () => _rooms.remove(key),
      ),
    );
    return room.add(onChange, onJoined);
  }
}

class _MeetupRoom {
  _MeetupRoom(this._socket, this.sessionId, this._currentAccount, this._remove);
  final OutingChatSocketClient _socket;
  final String sessionId;
  final bool Function() _currentAccount;
  final void Function() _remove;
  final _subscribers = <_Subscription>{};
  StreamSubscription<bool>? _connections;
  StreamSubscription<SmartMeetupRealtimeEvent>? _events;
  Timer? _retry;
  int _attempts = 0;
  int _generation = 0;
  bool _joining = false;
  bool _joined = false;
  bool _joinedBefore = false;
  int? _joinedVersion;

  bool get _active => _subscribers.isNotEmpty && _currentAccount();

  SmartMeetupRealtimeSubscription add(
    void Function(SmartMeetupRealtimeEvent) onChange,
    void Function(int? version, bool reconnect) onJoined,
  ) {
    final subscription = _Subscription(this, onChange, onJoined);
    _subscribers.add(subscription);
    if (_connections == null) {
      _connections = _socket.connectionChanges.listen(_connectionChanged);
      _events = _socket.meetupChanges.listen(_changed);
      _socket.retain(this);
      if (_socket.isConnected) unawaited(_join());
    } else if (_joined) {
      scheduleMicrotask(() {
        if (_active && _subscribers.contains(subscription) && _joined) {
          onJoined(_joinedVersion, false);
        }
      });
    }
    return subscription;
  }

  void _changed(SmartMeetupRealtimeEvent event) {
    if (!_active || event.sessionId != sessionId) return;
    for (final subscription in _subscribers.toList()) {
      if (_subscribers.contains(subscription)) subscription.onChange(event);
    }
  }

  void _connectionChanged(bool connected) {
    if (connected) {
      unawaited(_join());
    } else {
      _generation++;
      _joining = _joined = false;
      _attempts = 0;
      _retry?.cancel();
      _retry = null;
    }
  }

  Future<void> _join() async {
    if (!_active ||
        _joining ||
        _joined ||
        _retry != null ||
        !_socket.isConnected) {
      return;
    }
    _joining = true;
    final generation = _generation;
    final response = await _socket.joinMeetup(sessionId);
    if (generation != _generation || !_active) return;
    _joining = false;
    if (response == null) return;
    final error = response['error'];
    if (error == 'FORBIDDEN' || error == 'UNAUTHORIZED') {
      _changed(
        SmartMeetupRealtimeEvent(
          sessionId: sessionId,
          change: SmartMeetupChange.subscriptionRevoked,
        ),
      );
      return;
    }
    if (response['ok'] != true && error != 'CLOSED' && _attempts < 3) {
      final delay = Duration(seconds: 1 << _attempts++);
      _retry = Timer(delay, () {
        _retry = null;
        unawaited(_join());
      });
      return;
    }
    // Stop on a definitive acknowledgement or a bounded retry failure. REST
    // still reconciles authoritative state if the transport could not join.
    _joined = true;
    final version = response['inputVersion'];
    _joinedVersion = version is int && version > 0 ? version : null;
    final reconnect = _joinedBefore;
    _joinedBefore = true;
    for (final subscription in _subscribers.toList()) {
      if (_subscribers.contains(subscription)) {
        subscription.onJoined(_joinedVersion, reconnect);
      }
    }
  }

  void release(_Subscription subscription) {
    if (!_subscribers.remove(subscription) || _subscribers.isNotEmpty) return;
    _generation++;
    _retry?.cancel();
    unawaited(_connections?.cancel());
    unawaited(_events?.cancel());
    if (_currentAccount()) _socket.leaveMeetup(sessionId);
    _socket.release(this);
    _remove();
  }
}

class _Subscription implements SmartMeetupRealtimeSubscription {
  _Subscription(this._room, this.onChange, this.onJoined);
  final _MeetupRoom _room;
  final void Function(SmartMeetupRealtimeEvent) onChange;
  final void Function(int? version, bool reconnect) onJoined;

  @override
  void dispose() => _room.release(this);
}
