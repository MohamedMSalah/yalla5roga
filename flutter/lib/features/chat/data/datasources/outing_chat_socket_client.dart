import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:yalla_5roga/core/error/error_blueprint_logger.dart';
import 'package:yalla_5roga/core/error/error_codes.dart';
import 'package:yalla_5roga/core/error/error_context.dart';
import 'package:yalla_5roga/core/error/exceptions.dart';
import 'package:yalla_5roga/features/chat/data/models/chat_message_model.dart';
import 'package:yalla_5roga/features/chat/domain/entities/chat_message.dart';

typedef OutingChatTokenProvider = Future<String?> Function({bool forceRefresh});

/// Socket.IO client for outing chat delivery (not persistence).
///
/// Messages are written via REST; this client only joins rooms and receives
/// `outing:message` / `outing:read` events. Presentation must not import this.
///
/// [baseUrl] must match Dio `API_BASE_URL`. Production builds already require
/// `https` there, which yields a `wss` Socket.IO transport.
class OutingChatSocketClient {
  OutingChatSocketClient({required this.baseUrl, required this.tokenProvider});

  final String baseUrl;
  final OutingChatTokenProvider tokenProvider;

  io.Socket? _socket;
  final _desiredOutingIds = <String>{};
  final _messageController = StreamController<ChatMessage>.broadcast();
  final _readController =
      StreamController<OutingChatReadSocketEvent>.broadcast();
  final _connectionController = StreamController<bool>.broadcast();
  Completer<void>? _connectCompleter;
  var _connecting = false;
  var _disposed = false;
  var _authRetryScheduled = false;

  Stream<ChatMessage> get messages => _messageController.stream;
  Stream<OutingChatReadSocketEvent> get reads => _readController.stream;
  Stream<bool> get connectionChanges => _connectionController.stream;

  bool get isConnected => _socket?.connected ?? false;

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

    _connecting = true;
    _connectCompleter = Completer<void>();
    try {
      final token = await tokenProvider();
      if (token == null || token.isEmpty) {
        debugPrint('[OutingChatSocket] no Firebase ID token; skip connect');
        return;
      }

      final socket = io.io(
        baseUrl,
        io.OptionBuilder()
            .setTransports(['websocket'])
            .disableAutoConnect()
            .enableForceNew()
            .enableReconnection()
            .setReconnectionAttempts(12)
            .setReconnectionDelay(1000)
            .setReconnectionDelayMax(8000)
            // Auth callback runs on every (re)connect — never trust client userId.
            .setAuthFn((callback) {
              tokenProvider(forceRefresh: true)
                  .then((fresh) {
                    callback({'token': fresh ?? token});
                  })
                  .catchError((Object error) {
                    debugPrint('[OutingChatSocket] auth token error: $error');
                    callback({'token': token});
                  });
            })
            .build(),
      );

      socket.onConnect((_) {
        debugPrint('[OutingChatSocket] connected');
        _authRetryScheduled = false;
        _emitConnection(true);
        if (!(_connectCompleter?.isCompleted ?? true)) {
          _connectCompleter?.complete();
        }
        unawaited(_rejoinAll());
      });
      socket.onDisconnect((_) {
        debugPrint('[OutingChatSocket] disconnected');
        _emitConnection(false);
      });
      socket.onConnectError((error) {
        ErrorBlueprintLogger.log(
          error: ServerException(error.toString(), ErrorCodes.socket),
          context: const ErrorContext(
            feature: 'Chat',
            layer: 'Socket',
            operation: 'Connect',
            endpoint: '/socket.io',
          ),
          possibleCause:
              'Socket.IO connect failed — auth token, network, or server down',
        );
        _emitConnection(false);
        if (!(_connectCompleter?.isCompleted ?? true)) {
          _connectCompleter?.complete();
        }
        _scheduleAuthRetryIfNeeded(error);
      });
      socket.on('outing:message', _onMessage);
      socket.on('outing:read', _onRead);

      _socket = socket;
      socket.connect();
      await _connectCompleter!.future.timeout(
        const Duration(seconds: 10),
        onTimeout: () {},
      );
    } finally {
      _connecting = false;
    }
  }

  Future<void> joinOuting(String outingId) async {
    if (_disposed || outingId.isEmpty) return;
    _desiredOutingIds.add(outingId);
    await ensureConnected();
    final socket = _socket;
    if (socket == null || !socket.connected) return;

    final ack = await _emitWithAck(socket, 'outing:join', {
      'outingId': outingId,
    });
    if (ack['ok'] == true) return;

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
    // Only drop intent on definitive authZ rejection — keep set for retries.
    if (error == 'FORBIDDEN' || error == 'UNAUTHORIZED') {
      _desiredOutingIds.remove(outingId);
    }
  }

  Future<void> leaveOuting(String outingId) async {
    _desiredOutingIds.remove(outingId);
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
    _desiredOutingIds.clear();
    await _disposeSocket();
    _emitConnection(false);
  }

  Future<void> dispose() async {
    _disposed = true;
    await disconnect();
    await _messageController.close();
    await _readController.close();
    await _connectionController.close();
  }

  Future<void> _rejoinAll() async {
    final ids = _desiredOutingIds.toList();
    for (final outingId in ids) {
      await joinOuting(outingId);
    }
  }

  void _scheduleAuthRetryIfNeeded(dynamic error) {
    if (_disposed || _authRetryScheduled || _desiredOutingIds.isEmpty) return;
    final text = error.toString().toLowerCase();
    final unauthorized =
        text.contains('unauthorized') ||
        text.contains('auth') && text.contains('fail');
    if (!unauthorized) return;

    _authRetryScheduled = true;
    unawaited(() async {
      await Future<void>.delayed(const Duration(milliseconds: 400));
      if (_disposed) return;
      await _disposeSocket();
      _authRetryScheduled = false;
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
