import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:yalla_5roga/core/network/realtime_change.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:yalla_5roga/core/error/error_blueprint_logger.dart';
import 'package:yalla_5roga/core/error/error_codes.dart';
import 'package:yalla_5roga/core/error/error_context.dart';
import 'package:yalla_5roga/core/error/exceptions.dart';
import 'package:yalla_5roga/features/chat/data/models/chat_message_model.dart';
import 'package:yalla_5roga/features/chat/domain/entities/chat_message.dart';

typedef OutingChatTokenProvider = Future<String?> Function({bool forceRefresh});

/// Shared session Socket.IO client for chat and domain changes.
///
/// Messages are written via REST. Chat, arrivals and the app coordinator share
/// this transport; authorized rooms do not create additional connections.
///
/// [baseUrl] must match Dio `API_BASE_URL`. Production builds already require
/// `https` there, which yields a `wss` Socket.IO transport.
class OutingChatSocketClient {
  OutingChatSocketClient({required this.baseUrl, required this.tokenProvider});

  final String baseUrl;
  final OutingChatTokenProvider tokenProvider;

  io.Socket? _socket;
  final _desiredOutingIds = <String>{};
  final _desiredGroupIds = <String>{};
  final _joinedGroups = <String>{};
  final _joiningGroups = <String, Future<void>>{};
  final _messageController = StreamController<ChatMessage>.broadcast();
  final _readController =
      StreamController<OutingChatReadSocketEvent>.broadcast();
  final _arrivalController = StreamController<String>.broadcast();
  final _dataController = StreamController<RealtimeChange>.broadcast();
  Stream<RealtimeChange> get dataChanges => _dataController.stream;

  int _session = 0;
  int get sessionGeneration => _session;
  final _dataCursor = RealtimeCursor();
  Future<bool>? _reconciling;
  final _joined = <String>{};
  final _rejectedRooms = <String>{};
  final _joinRetries = <String, Timer>{};
  final _joinAttempts = <String, int>{};
  final _joining = <String, Future<void>>{};
  final _connectionController = StreamController<bool>.broadcast();
  Completer<void>? _connectCompleter;
  var _connecting = false;
  var _disposed = false;
  var _authRetryScheduled = false;
  var _forceTokenRefresh = false;
  int _authAttempts = 0;

  Stream<ChatMessage> get messages => _messageController.stream;
  Stream<OutingChatReadSocketEvent> get reads => _readController.stream;
  Stream<String> get arrivalChanges => _arrivalController.stream;
  Stream<bool> get connectionChanges => _connectionController.stream;

  bool get isConnected => _socket?.connected ?? false;
  bool _unavailable = false;
  bool _networkAvailable = true;
  bool get isReconnecting => !_unavailable && (_connecting || _socket != null);
  bool isRoomConnected(String id) =>
      _networkAvailable && isConnected && _joined.contains(id);
  bool isRoomReconnecting(String id) =>
      _networkAvailable && isReconnecting && !_rejectedRooms.contains(id);

  void setNetworkAvailable(bool online) {
    _networkAvailable = online;
    _emitConnection(isConnected);
  }

  /// Rooms the app intends to occupy (survive transient join failures).
  Set<String> get joinedOutingIds => Set.unmodifiable(_desiredOutingIds);

  Future<void> ensureConnected() async {
    if (_disposed) return;
    if (_socket?.connected == true) return;
    if (_connecting) {
      await (_connectCompleter?.future ?? Future<void>.value());
      return;
    }

    // Prefer Socket.IO reconnection on an existing manager over a second socket.
    final existing = _socket;
    if (existing != null) {
      if (!existing.connected) {
        existing.connect();
        await (_connectCompleter?.future ??
            Future<void>.delayed(const Duration(milliseconds: 50)));
      }
      return;
    }

    final session = _session;
    _connecting = true;
    _emitConnection(false);
    _connectCompleter = Completer<void>();
    try {
      final token = await tokenProvider(forceRefresh: _forceTokenRefresh);
      _forceTokenRefresh = false;
      if (session != _session) return;
      if (token == null || token.isEmpty) {
        _scheduleAuthRetryIfNeeded('unauthorized');
        return;
      }

      final socket = io.io(
        baseUrl,
        io.OptionBuilder()
            .setTransports(['websocket'])
            .disableAutoConnect()
            .enableForceNew()
            .enableReconnection()
            .setReconnectionDelay(1000)
            .setReconnectionDelayMax(8000)
            // Auth callback runs on every (re)connect â€” never trust client userId.
            .setAuthFn((callback) {
              tokenProvider()
                  .then((fresh) {
                    if (_disposed || session != _session) return;
                    callback({'token': fresh ?? token});
                  })
                  .catchError((Object error) {
                    if (_disposed || session != _session) return;
                    debugPrint('[OutingChatSocket] auth token error: $error');
                    callback({'token': token});
                  });
            })
            .build(),
      );

      socket.onConnect((_) {
        if (_disposed || session != _session) return;
        _unavailable = false;
        debugPrint('[OutingChatSocket] connected');
        _authRetryScheduled = false;
        _authAttempts = 0;
        _emitConnection(true);
        if (!(_connectCompleter?.isCompleted ?? true)) {
          _connectCompleter?.complete();
        }
        unawaited(_rejoinAll());
      });
      socket.onDisconnect((_) {
        if (_disposed || session != _session) return;
        _joinedGroups.clear();
        _joiningGroups.clear();
        _joined.clear();
        _joining.clear();
        debugPrint('[OutingChatSocket] disconnected');
        _emitConnection(false);
      });
      socket.io.on('reconnect_failed', (_) {
        if (_disposed || session != _session) return;
        _unavailable = true;
        _emitConnection(false);
      });
      socket.io.on('reconnect_attempt', (_) {
        if (_disposed || session != _session) return;
        _unavailable = false;
        _emitConnection(false);
      });
      socket.onConnectError((error) {
        if (_disposed || session != _session) return;
        _unavailable = true;
        ErrorBlueprintLogger.log(
          error: ServerException(error.toString(), ErrorCodes.socket),
          context: const ErrorContext(
            feature: 'Chat',
            layer: 'Socket',
            operation: 'Connect',
            endpoint: '/socket.io',
          ),
          possibleCause: 'Socket.IO connect failed â€” auth token, network, or server down',
        );
        _emitConnection(false);
        if (!(_connectCompleter?.isCompleted ?? true)) {
          _connectCompleter?.complete();
        }
        _scheduleAuthRetryIfNeeded(error);
      });
      socket.on('data:changed', (dynamic raw) {
        final data = _asStringKeyedMap(raw);
        final kind = data?['kind'];
        final id = data?['id'];
        if (!_disposed &&
            session == _session &&
            kind is String &&
            _dataCursor.accept(_asStringKeyedMap(data?['cursor']))) {
          _dataController.add(
            RealtimeChange(
              kind: kind,
              id: id is String ? id : null,
              payload: _asStringKeyedMap(data?['payload']),
              session: session,
            ),
          );
        }
      });
      socket.on('outing:message', (raw) {
        if (session == _session) _onMessage(raw);
      });
      socket.on('outing:read', (raw) {
        if (session == _session) _onRead(raw);
      });
      socket.on('outing:arrival_changed', (dynamic raw) {
        final id = _asStringKeyedMap(raw)?['outing_id'];
        if (!_disposed &&
            session == _session &&
            id is String &&
            id.isNotEmpty) {
          _arrivalController.add(id);
        }
      });

      _socket = socket;
      socket.connect();
      await _connectCompleter!.future.timeout(
        const Duration(seconds: 10),
        onTimeout: () {},
      );
    } catch (error) {
      if (session == _session) {
        _emitConnection(false);
        _scheduleAuthRetryIfNeeded('unauthorized');
      }
    } finally {
      if (session == _session) {
        _connecting = false;
        if (!(_connectCompleter?.isCompleted ?? true)) {
          _connectCompleter?.complete();
        }
      }
    }
  }

  Future<void> joinOuting(String outingId) async {
    if (_disposed || outingId.isEmpty) return;
    _desiredOutingIds.add(outingId);
    await ensureConnected();
    final socket = _socket;
    if (socket == null ||
        !socket.connected ||
        !_desiredOutingIds.contains(outingId) ||
        _joined.contains(outingId)) {
      return;
    }
    return _joining.putIfAbsent(outingId, () {
      final join = _join(socket, outingId);
      unawaited(
        join.whenComplete(() {
          if (identical(_joining[outingId], join)) _joining.remove(outingId);
        }),
      );
      return join;
    });
  }

  Future<void> _join(io.Socket socket, String outingId) async {
    final connection = socket.id;
    final ack = await _emitWithAck(socket, 'outing:join', {
      'outingId': outingId,
    });
    if (_socket != socket || socket.id != connection) return;
    if (ack['ok'] == true) {
      if (_desiredOutingIds.contains(outingId)) {
        _joined.add(outingId);
        _rejectedRooms.remove(outingId);
        _joinRetries.remove(outingId)?.cancel();
        _joinAttempts.remove(outingId);
        _emitConnection(true);
      } else {
        await leaveOuting(outingId);
      }
      return;
    }

    final error = ack['error']?.toString() ?? 'JOIN_FAILED';
    ErrorBlueprintLogger.log(
      error: ServerException(
        error,
        error == 'UNAUTHORIZED'
            ? ErrorCodes.unauthorized
            : error == 'FORBIDDEN'
            ? ErrorCodes.forbidden
            : ErrorCodes.socket,
      ),
      context: const ErrorContext(
        feature: 'Chat',
        layer: 'Socket',
        operation: 'Join outing room',
        endpoint: 'outing:join',
      ),
      possibleCause: 'Not a chat participant or socket auth rejected',
    );
    // Only drop intent on definitive authZ rejection â€” keep set for retries.
    if (error == 'FORBIDDEN' || error == 'UNAUTHORIZED') {
      _desiredOutingIds.remove(outingId);
      _rejectedRooms.add(outingId);
    } else if (_desiredOutingIds.contains(outingId)) {
      final attempt = _joinAttempts.update(
        outingId,
        (n) => n + 1,
        ifAbsent: () => 0,
      );
      _joinRetries.remove(outingId)?.cancel();
      _joinRetries[outingId] = Timer(
        Duration(seconds: 1 << attempt.clamp(0, 5)),
        () {
          _joinRetries.remove(outingId);
          if (!_disposed && _desiredOutingIds.contains(outingId)) {
            unawaited(joinOuting(outingId));
          }
        },
      );
    }
    _emitConnection(isConnected);
  }

  Future<void> leaveOuting(String outingId) async {
    _joinRetries.remove(outingId)?.cancel();
    _joinAttempts.remove(outingId);
    _rejectedRooms.remove(outingId);
    _desiredOutingIds.remove(outingId);
    _joined.remove(outingId);
    final socket = _socket;
    if (socket == null || !socket.connected) return;
    await _emitWithAck(socket, 'outing:leave', {'outingId': outingId});
  }

  /// Re-assert connection + rooms after foreground resume / network regain.
  Future<void> recover() async {
    if (_disposed) return;
    await ensureConnected();
    await _rejoinAll();
  }

  Future<void> disconnect() async {
    _session++;
    _dataCursor.clear();
    _reconciling = null;
    _connecting = false;
    _authRetryScheduled = false;
    _forceTokenRefresh = false;
    _authAttempts = 0;
    _desiredOutingIds.clear();
    _desiredGroupIds.clear();
    _joinedGroups.clear();
    _joiningGroups.clear();
    for (final timer in _joinRetries.values) {
      timer.cancel();
    }
    _joinRetries.clear();
    _joinAttempts.clear();
    _rejectedRooms.clear();
    _joined.clear();
    _joining.clear();
    await _disposeSocket();
    _emitConnection(false);
  }

  Future<void> dispose() async {
    _disposed = true;
    await disconnect();
    await _messageController.close();
    await _readController.close();
    await _connectionController.close();
    await _arrivalController.close();
    await _dataController.close();
  }

  Future<void> _rejoinAll() async {
    await Future.wait(_desiredOutingIds.toList().map(joinOuting));
    await syncGroups(_desiredGroupIds.toList());
  }

  /// Synchronizes authorized group subscriptions on the same session socket.
  Future<void> syncGroups(Iterable<String> ids) async {
    final desired = ids.toSet();
    final removed = _desiredGroupIds.difference(desired);
    _desiredGroupIds
      ..clear()
      ..addAll(desired);
    final socket = _socket;
    if (socket == null || !socket.connected) return;
    for (final id in removed) {
      _joinedGroups.remove(id);
      socket.emit('group:leave', {'groupId': id});
    }
    await Future.wait(
      desired.map(
        (id) => _joiningGroups
            .putIfAbsent(id, () async {
              if (_joinedGroups.contains(id)) return;
              final connection = socket.id;
              final ack = await _emitWithAck(socket, 'group:join', {
                'groupId': id,
              });
              if (_socket != socket || socket.id != connection) return;
              if (ack['ok'] == true && _desiredGroupIds.contains(id)) {
                _joinedGroups.add(id);
              }
              if (!_desiredGroupIds.contains(id)) {
                socket.emit('group:leave', {'groupId': id});
              }
            })
            .whenComplete(() => _joiningGroups.remove(id)),
      ),
    );
  }

  /// Replay only missed invalidations. False requests a bounded stale-cache fallback.
  Future<bool> reconcileData() {
    final session = _session;
    return _reconciling ??= _reconcileData().whenComplete(() {
      if (session == _session) _reconciling = null;
    });
  }

  Future<bool> _reconcileData() async {
    final socket = _socket;
    final session = _session;
    if (socket == null || !socket.connected) return false;
    final result = await _emitWithAck(
      socket,
      'data:reconcile',
      _dataCursor.checkpoint ?? {},
    );
    if (_disposed || session != _session || result['ok'] != true) return false;
    _dataCursor.acknowledge(_asStringKeyedMap(result['cursor']));
    final changes = result['changes'];
    if (changes is List) {
      for (final raw in changes) {
        final change = _asStringKeyedMap(raw);
        final kind = change?['kind'];
        if (kind is String &&
            _dataCursor.accept(_asStringKeyedMap(change?['cursor']))) {
          _dataController.add(
            RealtimeChange(
              kind: kind,
              id: change?['id'] as String?,
              session: session,
            ),
          );
        }
      }
    }
    return result['reset'] == false;
  }

  void _scheduleAuthRetryIfNeeded(dynamic error) {
    if (_disposed || _authRetryScheduled) return;
    final text = error.toString().toLowerCase();
    final unauthorized =
        text.contains('unauthorized') ||
        text.contains('auth') && text.contains('fail');
    if (!unauthorized) return;

    _authRetryScheduled = true;
    final session = _session;
    final seconds = 1 << _authAttempts.clamp(0, 6);
    _authAttempts++;
    unawaited(() async {
      await Future<void>.delayed(Duration(seconds: seconds));
      if (_disposed || session != _session) return;
      await _disposeSocket();
      if (_disposed || session != _session) return;
      _authRetryScheduled = false;
      _forceTokenRefresh = true;
      await ensureConnected();
    }());
  }

  void _onMessage(dynamic raw) {
    if (_disposed || _messageController.isClosed) return;
    final map = _asStringKeyedMap(raw);
    if (map == null) return;
    final message = ChatMessageModel.fromJson(map);
    if (message.id.isEmpty) return;
    _messageController.add(message);
  }

  void _onRead(dynamic raw) {
    if (_disposed || _readController.isClosed) return;
    final map = _asStringKeyedMap(raw);
    if (map == null) return;
    final outingId = (map['outing_id'] ?? map['outingId'])?.toString() ?? '';
    final userId = (map['user_id'] ?? map['userId'])?.toString() ?? '';
    if (outingId.isEmpty || userId.isEmpty) return;
    final lastReadRaw = map['last_read_at'] ?? map['lastReadAt'];
    _readController.add(
      OutingChatReadSocketEvent(
        outingId: outingId,
        userId: userId,
        lastReadAt: DateTime.tryParse(lastReadRaw?.toString() ?? ''),
      ),
    );
  }

  void _emitConnection(bool connected) {
    if (_disposed || _connectionController.isClosed) return;
    _connectionController.add(connected);
  }

  Future<Map<String, dynamic>> _emitWithAck(
    io.Socket socket,
    String event,
    Map<String, dynamic> payload,
  ) {
    final completer = Completer<Map<String, dynamic>>();
    socket.emitWithAck(
      event,
      payload,
      ack: (dynamic response) {
        final map = _asStringKeyedMap(response) ?? <String, dynamic>{};
        if (!completer.isCompleted) completer.complete(map);
      },
    );
    return completer.future.timeout(
      const Duration(seconds: 8),
      onTimeout: () => {'ok': false, 'error': 'ACK_TIMEOUT'},
    );
  }

  Future<void> _disposeSocket() async {
    final socket = _socket;
    _socket = null;
    if (!(_connectCompleter?.isCompleted ?? true)) {
      _connectCompleter?.complete();
    }
    _connectCompleter = null;
    if (socket == null) return;
    try {
      socket.clearListeners();
      socket.dispose();
    } catch (error) {
      debugPrint('[OutingChatSocket] dispose error: $error');
    }
  }

  Map<String, dynamic>? _asStringKeyedMap(dynamic raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) {
      return {
        for (final entry in raw.entries) entry.key.toString(): entry.value,
      };
    }
    return null;
  }
}

class OutingChatReadSocketEvent {
  const OutingChatReadSocketEvent({
    required this.outingId,
    required this.userId,
    this.lastReadAt,
  });

  final String outingId;
  final String userId;
  final DateTime? lastReadAt;
}
