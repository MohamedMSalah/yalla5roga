import 'package:yalla_5roga/core/network/api_payload.dart';
import 'package:yalla_5roga/features/chat/domain/entities/outing_chat_read_result.dart';

class OutingChatReadResultModel extends OutingChatReadResult {
  const OutingChatReadResultModel({
    required super.outingId,
    required super.unreadCount,
    required super.unreadChatCount,
  });

  factory OutingChatReadResultModel.fromJson(
    Map<String, dynamic> json, {
    required String outingId,
  }) {
    final resolvedOutingId =
        apiString(json['outing_id']) ?? apiString(json['outingId']) ?? outingId;

    // Backend mark-read returns the chat_reads row. Optional unread fields
    // may appear later; default to 0 after a successful upsert.
    final unreadCount = json.containsKey('unread_count')
        ? apiInt(json['unread_count'])
        : apiInt(json['unreadCount']);
    final unreadChatCount = json.containsKey('unread_chat_count')
        ? apiInt(json['unread_chat_count'])
        : (json.containsKey('unreadChatCount')
              ? apiInt(json['unreadChatCount'])
              : unreadCount);

    return OutingChatReadResultModel(
      outingId: resolvedOutingId,
      unreadCount: unreadCount,
      unreadChatCount: unreadChatCount,
    );
  }
}
