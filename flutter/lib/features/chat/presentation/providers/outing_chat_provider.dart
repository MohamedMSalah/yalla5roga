import 'package:flutter/foundation.dart';
import 'package:yalla_5roga/core/error/app_error_feedback.dart';
import 'package:yalla_5roga/features/chat/domain/entities/chat_message.dart';
import 'package:yalla_5roga/features/chat/domain/repositories/outing_chat_repository.dart';

class OutingChatProvider extends ChangeNotifier {
  OutingChatProvider({required this.repository});

  final OutingChatRepository repository;

  var _messages = <String, List<ChatMessage>>{};
  var _loading = <String, bool>{};
  var _loaded = <String, bool>{};
  var _sending = <String, bool>{};
  var _unread = <String, int>{};
  int _unreadChatCount = 0;
  String? _errorMessage;

  int get unreadChatCount => _unreadChatCount;

  bool get isInitialLoading => false;

  String? get errorMessage => _errorMessage;

  int unreadFor(String outingId) => _unread[outingId] ?? 0;

  List<ChatMessage> messagesFor(String outingId) =>
      List.unmodifiable(_messages[outingId] ?? const []);

  bool isLoading(String outingId) => _loading[outingId] ?? false;

  bool hasLoaded(String outingId) => _loaded[outingId] ?? false;

  bool isSending(String outingId) => _sending[outingId] ?? false;

  bool isInitialLoadingFor(String outingId) =>
      isLoading(outingId) && messagesFor(outingId).isEmpty && !hasLoaded(outingId);

  Future<void> load(
    String outingId, {
    bool forceRefresh = false,
    String? userId,
  }) async {
    final cached = repository.cachedMessages(outingId);
    if (cached.isNotEmpty) {
      _messages[outingId] = _withMine(cached, userId);
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
        _errorMessage = failure.message;
        if (messagesFor(outingId).isEmpty) {
          AppErrorFeedback.report(
            failure,
            kind: AppErrorKind.load,
            context: 'loadOutingChat',
          );
        }
      },
      (items) {
        _messages[outingId] = _withMine(items, userId);
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
        _errorMessage = failure.message;
        AppErrorFeedback.report(
          failure,
          kind: AppErrorKind.send,
          context: 'sendOutingChat',
        );
      },
      (message) {
        _messages[outingId] = _upsert(messagesFor(outingId), message);
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
    _messages = {};
    _loading = {};
    _loaded = {};
    _sending = {};
    _unread = {};
    _unreadChatCount = 0;
    _errorMessage = null;
    repository.clearCache();
    notifyListeners();
  }

  List<ChatMessage> _withMine(List<ChatMessage> items, String? userId) {
    if (userId == null || userId.isEmpty) return List.of(items);
    return [
      for (final item in items)
        item.copyWith(isMine: item.senderId == userId || item.isMine),
    ];
  }

  List<ChatMessage> _upsert(List<ChatMessage> items, ChatMessage message) {
    final without = [
      for (final item in items)
        if (item.id != message.id) item,
    ];
    final next = [...without, message]
      ..sort((a, b) {
        final aTime = a.sentAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bTime = b.sentAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return aTime.compareTo(bTime);
      });
    return next;
  }
}
