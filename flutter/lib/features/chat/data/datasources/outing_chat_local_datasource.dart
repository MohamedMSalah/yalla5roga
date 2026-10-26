import 'dart:convert';

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
  OutingChatLocalDataSourceImpl(this._prefs) {
    _load();
  }

  final SharedPreferences _prefs;
  var _byOuting = <String, List<ChatMessage>>{};

  void _load() {
    final raw = _prefs.getString(AppConstants.outingChatMessagesKey);
    if (raw == null) return;
    final decoded = jsonDecode(raw);
    if (decoded is! Map) return;
    _byOuting = {
      for (final entry in decoded.entries)
        if (entry.value is List)
          '${entry.key}': [
            for (final item in entry.value as List)
              if (item is Map)
                ChatMessageModel.fromJson(
                  item,
                  outingId: '${entry.key}',
                ),
          ],
    };
  }

  Future<void> _persist() {
    return _prefs.setString(
      AppConstants.outingChatMessagesKey,
      jsonEncode({
        for (final entry in _byOuting.entries)
          entry.key: [for (final item in entry.value) item.toJson()],
      }),
    );
  }

  @override
  List<ChatMessage> getMessages(String outingId) {
    return List.unmodifiable(_byOuting[outingId] ?? const []);
  }

  @override
  Future<List<ChatMessage>> saveMessages(
    String outingId,
    List<ChatMessage> messages,
  ) async {
    _byOuting[outingId] = List.of(messages);
    await _persist();
    return getMessages(outingId);
  }

  @override
  Future<void> clear() async {
    _byOuting = {};
    await _prefs.remove(AppConstants.outingChatMessagesKey);
  }
}
