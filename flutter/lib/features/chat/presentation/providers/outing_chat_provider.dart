import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:yalla_5roga/core/error/app_error_feedback.dart';
import 'package:yalla_5roga/features/chat/data/datasources/outing_chat_socket_client.dart';
import 'package:yalla_5roga/features/chat/domain/entities/chat_message.dart';
import 'package:yalla_5roga/features/chat/domain/outing_chat_message_merge.dart';
import 'package:yalla_5roga/features/chat/domain/repositories/outing_chat_repository.dart';

class OutingChatProvider extends ChangeNotifier {
  OutingChatProvider({
    required this.repository,
    OutingChatSocketClient? socketClient,
  }) : _socket = socketClient {
    final socket = _socket;
    if (socket == null) return;
    _messageSub = socket.messages.listen(_onSocketMessage);
    _connectionSub = socket.connectionChanges.listen(_onConnectionChange);
  }

  final OutingChatRepository repository;
  final OutingChatSocketClient? _socket;

  StreamSubscription<ChatMessage>? _messageSub;
  StreamSubscription<bool>? _connectionSub;
  Timer? _recoveryDebounce;

  var _messages = <String, List<ChatMessage>>{};
  var _loading = <String, bool>{};
  var _loaded = <String, bool>{};
  var _sending = <String, bool>{};
  var _unread = <String, int>{};
  var _activeOutingIds = <String>{};
  String? _currentUserId;
  int _unreadChatCount = 0;
  String? _errorMessage;

  int get unreadChatCount => _unreadChatCount;

  bool get isInitialLoading => false;

  String? get errorMessage => _errorMessage;

  bool get isSocketConnected => _socket?.isConnected ?? false;

  int unreadFor(String outingId) => _unread[outingId] ?? 0;

  List<ChatMessage> messagesFor(String outingId) =>
      List.unmodifiable(_messages[outingId] ?? const []);

  bool isLoading(String outingId) => _loading[outingId] ?? false;

  bool hasLoaded(String outingId) => _loaded[outingId] ?? false;

  bool isSending(String outingId) => _sending[outingId] ?? false;

  bool isInitialLoadingFor(String outingId) =>
      isLoading(outingId) &&
      messagesFor(outingId).isEmpty &&
      !hasLoaded(outingId);

  /// Opens REST history and joins the outing Socket.IO room for live delivery.
  Future<void> subscribe(
    String outingId, {
    String? userId,
    bool forceRefresh = false,
  }) async {
    if (userId != null && userId.isNotEmpty) {
      _currentUserId = userId;
    }
    _activeOutingIds.add(outingId);
    await load(outingId, forceRefresh: forceRefresh, userId: _currentUserId);
    await _socket?.joinOuting(outingId);
    await markRead(outingId);
  }

  Future<void> unsubscribe(String outingId) async {
    _activeOutingIds.remove(outingId);
    await _socket?.leaveOuting(outingId);
  }

  /// Foreground / network regain: rejoin rooms and REST-fill gaps.
  Future<void> recoverAfterResume({String? userId}) async {
    if (userId != null && userId.isNotEmpty) {
      _currentUserId = userId;
    }
    if (_activeOutingIds.isEmpty &&
        (_socket?.joinedOutingIds.isEmpty ?? true)) {
      return;
    }
    await _socket?.recover();
    await _recoverActiveRoomsFromRest();
  }

  Future<void> load(
    String outingId, {
    bool forceRefresh = false,
    String? userId,
  }) async {
    if (userId != null && userId.isNotEmpty) {
      _currentUserId = userId;
    }

    final cached = repository.cachedMessages(outingId);
    if (cached.isNotEmpty) {
      _messages[outingId] = _withMine(cached, _currentUserId);
      notifyListeners();
    }

    _loading[outingId] = true;
    _errorMessage = null;
    notifyListeners();

    final result = await repository.getMessages(
      outingId,
      forceRefresh: forceRefresh,
    );
    result.fold(
      (failure) {
        _errorMessage = AppErrorFeedback.messageOf(failure);
        if (messagesFor(outingId).isEmpty) {
          AppErrorFeedback.report(
            failure,
            kind: AppErrorKind.load,
            context: 'loadOutingChat',
          );
        }
      },
      (items) {
        _messages[outingId] = _withMine(items, _currentUserId);
        _errorMessage = null;
      },
    );
    _loading[outingId] = false;
    _loaded[outingId] = true;
    notifyListeners();
  }

  Future<bool> sendMessage({
    required String outingId,
    required String text,
    required String senderId,
    required String senderName,
    String? avatar,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || isSending(outingId)) return false;

    _currentUserId = senderId;
    _sending[outingId] = true;
    notifyListeners();

    final result = await repository.sendMessage(
      outingId: outingId,
      text: trimmed,
      senderId: senderId,
      senderName: senderName,
      avatar: avatar,
    );

    var ok = false;
    result.fold(
      (failure) {
        _errorMessage = AppErrorFeedback.messageOf(failure);
        AppErrorFeedback.report(
          failure,
          kind: AppErrorKind.send,
          context: 'sendOutingChat',
        );
      },
      (message) {
        // REST response is canonical; socket echo dedupes by id in upsert.
        _messages[outingId] = upsertOutingChatMessage(
          messagesFor(outingId),
          message.copyWith(isMine: true),
        );
        _errorMessage = null;
        ok = true;
      },
    );
    _sending[outingId] = false;
    notifyListeners();
    return ok;
  }

  Future<void> markRead(String outingId) async {
    final result = await repository.markRead(outingId);
    result.fold((_) {}, (read) {
      _unread[outingId] = read.unreadCount;
      _unreadChatCount = read.unreadChatCount;
      notifyListeners();
    });
  }

  void clear() {
    _recoveryDebounce?.cancel();
    _recoveryDebounce = null;
    final active = _activeOutingIds.toList();
    _activeOutingIds = {};
    _messages = {};
    _loading = {};
    _loaded = {};
    _sending = {};
    _unread = {};
    _unreadChatCount = 0;
    _errorMessage = null;
    _currentUserId = null;
    repository.clearCache();
    unawaited(() async {
      for (final outingId in active) {
        await _socket?.leaveOuting(outingId);
      }
      await _socket?.disconnect();
    }());
    notifyListeners();
  }

  @override
  void dispose() {
    _recoveryDebounce?.cancel();
    _messageSub?.cancel();
    _connectionSub?.cancel();
    unawaited(_socket?.dispose() ?? Future<void>.value());
    super.dispose();
  }

  void _onSocketMessage(ChatMessage message) {
    final outingId = message.outingId;
    if (outingId == null || outingId.isEmpty) return;
    if (!_activeOutingIds.contains(outingId) &&
        !(_socket?.joinedOutingIds.contains(outingId) ?? false)) {
      return;
    }

    final enriched = message.copyWith(
      isMine:
          (_currentUserId != null && message.senderId == _currentUserId) ||
          message.isMine,
    );
    _messages[outingId] = upsertOutingChatMessage(
      messagesFor(outingId),
      enriched,
    );
    notifyListeners();
  }

  void _onConnectionChange(bool connected) {
    if (!connected) return;
    // Debounce: connect + resume can fire close together.
    _recoveryDebounce?.cancel();
    _recoveryDebounce = Timer(const Duration(milliseconds: 250), () {
      unawaited(_recoverActiveRoomsFromRest());
    });
  }

  Future<void> _recoverActiveRoomsFromRest() async {
    for (final outingId in _activeOutingIds.toList()) {
      await load(outingId, forceRefresh: true, userId: _currentUserId);
    }
  }

  List<ChatMessage> _withMine(List<ChatMessage> items, String? userId) {
    if (userId == null || userId.isEmpty) return List.of(items);
    return [
      for (final item in items)
        item.copyWith(isMine: item.senderId == userId || item.isMine),
    ];
  }
}
