import 'dart:convert';
import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:yalla_5roga/core/constants/app_constants.dart';
import 'package:yalla_5roga/features/chat/data/models/chat_message_model.dart';
import 'package:yalla_5roga/features/chat/domain/entities/chat_message.dart';

abstract class OutingChatLocalDataSource {
  List<ChatMessage> getMessages(String outingId);
  Future<List<ChatMessage>> saveMessages(
    String outingId,
    List<ChatMessage> messages,
  );
  Future<void> clear();
}

class OutingChatLocalDataSourceImpl implements OutingChatLocalDataSource {
  OutingChatLocalDataSourceImpl(
    this._prefs, {
    String? Function()? userId,
    String? origin,
  }) : _userId = userId,
       _origin = origin {
    _uid = _userId?.call();
    _load();
  }

  final SharedPreferences _prefs;
  final String? Function()? _userId;
  final String? _origin;
  String? _uid;
  String? get _key => _userId == null
      ? AppConstants.outingChatMessagesKey
      : _uid == null
      ? null
      : '${AppConstants.outingChatMessagesKey}:$_origin:$_uid';

  void _switchAccount() {
    final uid = _userId?.call();
    if (_uid == uid) return;
    _persistTimer?.cancel();
    _byOuting = {};
    _uid = uid;
    _load();
  }

  static const _maxMessagesPerOuting = 100;
  static const _maxOutings = 20;
  static const _writeDebounce = Duration(milliseconds: 500);
  var _byOuting = <String, List<ChatMessage>>{};
  Timer? _persistTimer;

  void _load() {
    final key = _key;
    final raw = key == null ? null : _prefs.getString(key);
    if (raw == null) return;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return;
      _byOuting = {
        for (final entry in decoded.entries.take(_maxOutings))
          if (entry.value is List)
            '${entry.key}': [
              for (final item in (entry.value as List).take(
                _maxMessagesPerOuting,
              ))
                if (item is Map)
                  ChatMessageModel.fromJson(item, outingId: '${entry.key}'),
            ],
      };
    } catch (_) {
      // A corrupt cache must never prevent chat from loading remotely.
      _byOuting = {};
    }
  }

  Future<void> _persist() async {
    final key = _key;
    if (key == null) return;
    await _prefs.setString(
      key,
      jsonEncode({
        for (final entry in _byOuting.entries)
          entry.key: [
            for (final item in entry.value)
              if (!item.id.startsWith('local_')) item.toJson(),
          ],
      }),
    );
  }

  void _schedulePersist() {
    _persistTimer?.cancel();
    _persistTimer = Timer(_writeDebounce, () {
      _persistTimer = null;
      unawaited(_persist());
    });
  }

  @override
  List<ChatMessage> getMessages(String outingId) {
    _switchAccount();
    return List.unmodifiable(_byOuting[outingId] ?? const []);
  }

  @override
  Future<List<ChatMessage>> saveMessages(
    String outingId,
    List<ChatMessage> messages,
  ) async {
    _switchAccount();
    final retained = messages.length <= _maxMessagesPerOuting
        ? List<ChatMessage>.of(messages)
        : List<ChatMessage>.of(
            messages.sublist(messages.length - _maxMessagesPerOuting),
          );
    _byOuting.remove(outingId);
    _byOuting[outingId] = retained;
    while (_byOuting.length > _maxOutings) {
      _byOuting.remove(_byOuting.keys.first);
    }
    _schedulePersist();
    return getMessages(outingId);
  }

  @override
  Future<void> clear() async {
    _persistTimer?.cancel();
    _persistTimer = null;
    _byOuting = {};
    final key = _key;
    if (key != null) await _prefs.remove(key);
    await _prefs.remove(AppConstants.outingChatMessagesKey);
  }
}
