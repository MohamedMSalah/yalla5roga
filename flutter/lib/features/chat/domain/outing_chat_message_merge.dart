import 'package:yalla_5roga/features/chat/domain/entities/chat_message.dart';

bool isLocalPendingMessageId(String id) => id.startsWith('local_');

/// Upserts [message] into [items] by server id and drops matching optimistic
/// `local_*` rows so REST + socket delivery cannot double-render.
List<ChatMessage> upsertOutingChatMessage(
  List<ChatMessage> items,
  ChatMessage message,
) {
  final isServer = !isLocalPendingMessageId(message.id);
  if (!isServer && items.any((item) =>
      !isLocalPendingMessageId(item.id) && _sameOptimistic(message, item))) {
    return items;
  }
  final without = <ChatMessage>[
    for (final item in items)
      if (item.id != message.id &&
          !(isServer &&
              isLocalPendingMessageId(item.id) &&
              _sameOptimistic(item, message)))
        item,
  ];

  final next = [...without, message]
    ..sort((a, b) {
      final aTime = a.sentAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bTime = b.sentAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final byTime = aTime.compareTo(bTime);
      if (byTime != 0) return byTime;
      return a.id.compareTo(b.id);
    });
  return next;
}

bool _sameOptimistic(ChatMessage local, ChatMessage server) {
  if (local.clientMessageId != null || server.clientMessageId != null) {
    return local.clientMessageId != null &&
        local.clientMessageId == server.clientMessageId;
  }
  if (local.text != server.text) return false;
  if ((local.senderId ?? '') != (server.senderId ?? '')) return false;
  if (local.outingId != null &&
      server.outingId != null &&
      local.outingId != server.outingId) {
    return false;
  }
  return true;
}
