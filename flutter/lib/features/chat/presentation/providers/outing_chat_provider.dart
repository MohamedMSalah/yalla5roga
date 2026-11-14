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
    Stream<ChatMessage>? sendUpdates,
    this.onQueued,
    this.persistLiveMessage,
  }) : _socket = socketClient {
    _sendSub = sendUpdates?.listen(_applyLiveMessage);
    final socket = _socket;
    if (socket == null) return;
    _messageSub = socket.messages.listen(_onSocketMessage);
    _connectionSub = socket.connectionChanges.listen((_) => notifyListeners());
  }

  final OutingChatRepository repository;
  final OutingChatSocketClient? _socket;
  final VoidCallback? onQueued;
  final Future<void> Function(ChatMessage)? persistLiveMessage;
  StreamSubscription<ChatMessage>? _sendSub;

  StreamSubscription<ChatMessage>? _messageSub;
  StreamSubscription<bool>? _connectionSub;

  var _messages = <String, List<ChatMessage>>{};
  var _loading = <String, bool>{};
  var _loaded = <String, bool>{};
  final _loadingOlder = <String>{};
  final _liveDuringLoad = <String, List<ChatMessage>>{};
  var _generation = 0;
  var _sending = <String, bool>{};
  var _unread = <String, int>{};
  final _activeOutings = <String, int>{};
  String? _currentUserId;
  int _unreadChatCount = 0;
  String? _errorMessage;

  int get unreadChatCount => _unreadChatCount;

  bool get isInitialLoading => false;

  String? get errorMessage => _errorMessage;

  bool get isSocketConnected => _socket?.isConnected ?? false;
  bool get isReconnecting => _socket?.isReconnecting ?? false;
  bool isRoomConnected(String id) => _socket?.isRoomConnected(id) ?? false;
  bool isRoomReconnecting(String id) =>
      _socket?.isRoomReconnecting(id) ?? false;

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
    final subscriptions = _activeOutings.update(
      outingId,
      (n) => n + 1,
      ifAbsent: () => 1,
    );
    if (subscriptions == 1) unawaited(_socket?.joinOuting(outingId));
    final generation = _generation;
    await load(outingId, forceRefresh: forceRefresh, userId: _currentUserId);
    if (generation != _generation || !_activeOutings.containsKey(outingId)) {
      return;
    }
    await markRead(outingId);
  }

  Future<void> unsubscribe(String outingId) async {
    final subscriptions = _activeOutings[outingId] ?? 0;
    if (subscriptions > 1) {
      _activeOutings[outingId] = subscriptions - 1;
      return;
    }
    _activeOutings.remove(outingId);
    await _socket?.leaveOuting(outingId);
  }

  bool hasOlder(String outingId) => repository.hasOlderMessages(outingId);
  bool isLoadingOlder(String outingId) => _loadingOlder.contains(outingId);

  Future<void> loadOlder(String outingId) async {
    if (!hasOlder(outingId) || !_loadingOlder.add(outingId)) return;
    final generation = _generation;
    notifyListeners();
    final result = await repository.getOlderMessages(outingId);
    if (generation != _generation) return;
    _loadingOlder.remove(outingId);
    result.fold((failure) {
      AppErrorFeedback.report(
        failure,
        kind: AppErrorKind.load,
        context: 'loadOlderOutingChat',
      );
    }, (items) => _mergeMessages(outingId, items));
    notifyListeners();
  }

  void _mergeMessages(String outingId, List<ChatMessage> items) {
    var merged = messagesFor(outingId);
    for (final item in _withMine(items, _currentUserId)) {
      merged = upsertOutingChatMessage(merged, item);
    }
    _messages[outingId] = merged;
  }

  Future<void> load(
    String outingId, {
    bool forceRefresh = false,
    String? userId,
  }) async {
    if (userId != null && userId.isNotEmpty) {
      _currentUserId = userId;
    }

    if (isLoading(outingId)) return;
    final generation = _generation;
    final cached = repository.cachedMessages(outingId);
    if (cached.isNotEmpty) {
      _mergeMessages(outingId, cached);
      notifyListeners();
    }

    _loading[outingId] = true;
    _liveDuringLoad[outingId] = [];
    _errorMessage = null;
    notifyListeners();

    final result = await repository.getMessages(
      outingId,
      forceRefresh: forceRefresh,
    );
    if (generation != _generation) return;
    result.fold(
      (failure) {
        if (failure.statusCode == 401 ||
            failure.statusCode == 403 ||
            failure.statusCode == 404) {
          _messages.remove(outingId);
        }
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
        if (forceRefresh) {
          _messages[outingId] = _withMine(items, _currentUserId);
        } else {
          _mergeMessages(outingId, items);
        }
        _mergeMessages(outingId, _liveDuringLoad[outingId] ?? []);
        _errorMessage = null;
      },
    );
    _loading[outingId] = false;
    _liveDuringLoad.remove(outingId);
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

    final generation = _generation;
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

    if (generation != _generation) return false;
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
        if (message.deliveryStatus == MessageDeliveryStatus.pending) {
          onQueued?.call();
        }
      },
    );
    _sending[outingId] = false;
    notifyListeners();
    return ok;
  }

  Future<bool> mutateMessage(
    String outingId,
    String messageId, {
    String? text,
  }) async {
    if (isSending(outingId)) return false;
    _sending[outingId] = true;
    notifyListeners();
    final generation = _generation;
    final result = await repository.mutateMessage(
      outingId,
      messageId,
      text: text,
    );
    if (generation != _generation) return false;
    _sending[outingId] = false;
    notifyListeners();
    return result.fold(
      (failure) {
        AppErrorFeedback.report(
          failure,
          kind: AppErrorKind.send,
          context: 'mutateOutingChat',
        );
        return false;
      },
      (message) {
        _applyLiveMessage(message);
        return true;
      },
    );
  }

  Future<void> retryMessage(ChatMessage message) async {
    final generation = _generation;
    final result = await repository.retryMessage(message);
    if (generation != _generation) return;
    result.fold(
      (failure) => AppErrorFeedback.report(failure, kind: AppErrorKind.send),
      (pending) {
        _applyLiveMessage(pending);
        onQueued?.call();
      },
    );
  }

  Future<void> markRead(String outingId) async {
    final generation = _generation;
    if (_socket != null && !_socket.isConnected) return;
    final result = await repository.markRead(outingId);
    if (generation != _generation) return;
    result.fold((_) {}, (read) {
      _unread[outingId] = read.unreadCount;
      _unreadChatCount = read.unreadChatCount;
      notifyListeners();
    });
  }

  void clear() {
    _generation++;
    _loadingOlder.clear();
    _liveDuringLoad.clear();
    _activeOutings.clear();
    _messages = {};
    _loading = {};
    _loaded = {};
    _sending = {};
    _unread = {};
    _unreadChatCount = 0;
    _errorMessage = null;
    _currentUserId = null;
    repository.clearCache();
    unawaited(_socket?.disconnect());
    notifyListeners();
  }

  @override
  void dispose() {
    _messageSub?.cancel();
    _connectionSub?.cancel();
    _sendSub?.cancel();
    unawaited(_socket?.dispose() ?? Future<void>.value());
    super.dispose();
  }

  void _onSocketMessage(ChatMessage message) {
    final outingId = message.outingId;
    if (outingId == null || outingId.isEmpty) return;
    if (!_activeOutings.containsKey(outingId) &&
        !(_socket?.joinedOutingIds.contains(outingId) ?? false)) {
      return;
    }

    unawaited(persistLiveMessage?.call(message));
    _applyLiveMessage(message);
  }

  void _applyLiveMessage(ChatMessage message) {
    final outingId = message.outingId;
    if (outingId == null || !_activeOutings.containsKey(outingId)) return;
    _liveDuringLoad[outingId]?.add(message);
    final enriched = message.copyWith(
      isMine:
          (_currentUserId != null && message.senderId == _currentUserId) ||
          message.isMine,
    );
    final current = messagesFor(outingId);
    if (current.any(
      (item) =>
          item.id == enriched.id &&
          item.deliveryStatus == enriched.deliveryStatus &&
          item.text == enriched.text &&
          item.sender == enriched.sender,
    )) {
      return;
    }
    _messages[outingId] = upsertOutingChatMessage(current, enriched);
    notifyListeners();
  }

  Future<void> recoverActiveChats() async {
    if (_activeOutings.isEmpty) return;
    if (_socket?.isConnected == true) await _socket?.recover();
    for (final outingId in _activeOutings.keys.toList()) {
      await load(outingId, forceRefresh: true, userId: _currentUserId);
      if (_activeOutings.containsKey(outingId) && _errorMessage == null) {
        await markRead(outingId);
      }
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
