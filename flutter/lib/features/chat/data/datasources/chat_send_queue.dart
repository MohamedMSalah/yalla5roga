import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:yalla_5roga/core/error/exceptions.dart';
import 'package:yalla_5roga/features/chat/data/models/chat_message_model.dart';
import 'package:yalla_5roga/features/chat/domain/entities/chat_message.dart';

/// Only chat sends are replayed. Their client UUID is also the server dedupe key.
class ChatSendQueue {
  ChatSendQueue(this._prefs, this.userId, this.origin);

  final SharedPreferences _prefs;
  final String? Function() userId;
  final String origin;
  final _updates = StreamController<ChatMessage>.broadcast();
  Stream<ChatMessage> get updates => _updates.stream;
  int _generation = 0;
  Future<bool>? _drain;

  String _prefix(String uid) => 'chatQueue.v1:$origin:$uid:';

  bool get hasPending => messages.any(
    (message) => message.deliveryStatus == MessageDeliveryStatus.pending,
  );

  List<ChatMessage> get messages {
    final uid = userId();
    return uid == null ? [] : _read(uid);
  }

  List<ChatMessage> _read(String uid) {
    final prefix = _prefix(uid);
    final items = <ChatMessage>[];
    for (final key in _prefs.getKeys().where((key) => key.startsWith(prefix))) {
      try {
        final message = ChatMessageModel.fromJson(
          jsonDecode(_prefs.getString(key)!) as Map,
        );
        if (message.senderId == uid &&
            message.clientMessageId != null &&
            message.outingId != null &&
            message.sentAt != null) {
          items.add(message);
        }
      } catch (_) {
        // An unreadable record must not prevent other sends.
      }
    }
    items.sort((a, b) => a.sentAt!.compareTo(b.sentAt!));
    return items;
  }

  Future<void> add(ChatMessage message) async {
    final uid = userId();
    final generation = _generation;
    if (uid == null || uid != message.senderId) {
      throw const AuthException('Chat account changed');
    }
    final pending = _read(uid);
    if (!pending.any(
          (item) => item.clientMessageId == message.clientMessageId,
        ) &&
        pending
                .where(
                  (item) =>
                      item.deliveryStatus == MessageDeliveryStatus.pending,
                )
                .length >=
            100) {
      throw const CacheException('Chat send queue is full');
    }
    await _write(uid, message);
    if (generation != _generation || userId() != uid) {
      await _prefs.remove('${_prefix(uid)}${message.clientMessageId}');
      throw const AuthException('Chat account changed');
    }
  }

  Future<void> _write(String uid, ChatMessage message) async {
    final key = '${_prefix(uid)}${message.clientMessageId}';
    if (!await _prefs.setString(key, jsonEncode(message.toJson()))) {
      // Legacy preferences update their in-memory copy before the platform write.
      await _prefs.remove(key);
      throw const CacheException('Could not save the pending message');
    }
  }

  /// Returns whether another attempt is needed after a transient failure.
  Future<bool> flush(Future<ChatMessage> Function(ChatMessage) send) {
    return _drain ??= _flush(send).whenComplete(() => _drain = null);
  }

  Future<bool> _flush(Future<ChatMessage> Function(ChatMessage) send) async {
    final uid = userId();
    final generation = _generation;
    if (uid == null) return false;
    bool current() => generation == _generation && userId() == uid;

    for (final message in _read(uid)) {
      if (!current()) return false;
      if (message.deliveryStatus != MessageDeliveryStatus.pending) continue;
      final key = '${_prefix(uid)}${message.clientMessageId}';
      try {
        final saved = await send(message);
        if (!current()) return false;
        if (!await _prefs.remove(key)) return true;
        if (!current()) return false;
        _updates.add(saved);
      } on AppException catch (error) {
        if (!current()) return false;
        final status = error.statusCode;
        if (error is NetworkException ||
            status == 401 ||
            status == 408 ||
            status == 429 ||
            (status ?? 0) >= 500) {
          return true;
        }
        final failed = message.copyWith(
          deliveryStatus: MessageDeliveryStatus.failed,
        );
        await _write(uid, failed);
        if (!current()) return false;
        _updates.add(failed);
        final failures = _read(
          uid,
        ).where((item) => item.deliveryStatus == MessageDeliveryStatus.failed);
        for (final old in failures.take((failures.length - 30).clamp(0, 30))) {
          await _prefs.remove('${_prefix(uid)}${old.clientMessageId}');
        }
      }
    }
    return false;
  }

  Future<void> clear(String uid) async {
    _generation++;
    await Future.wait(
      _prefs
          .getKeys()
          .where((key) => key.startsWith(_prefix(uid)))
          .map(_prefs.remove),
    );
  }
}
