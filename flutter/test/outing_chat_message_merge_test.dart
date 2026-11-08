import 'package:flutter_test/flutter_test.dart';
import 'package:yalla_5roga/features/chat/domain/entities/chat_message.dart';
import 'package:yalla_5roga/features/chat/domain/outing_chat_message_merge.dart';

ChatMessage _msg({
  required String id,
  required String text,
  String? senderId,
  String? outingId,
  DateTime? sentAt,
}) {
  return ChatMessage(
    id: id,
    sender: 'User',
    text: text,
    time: '12:00 PM',
    isMine: senderId == 'me',
    senderId: senderId,
    outingId: outingId,
    sentAt: sentAt,
  );
}

void main() {
  group('upsertOutingChatMessage', () {
    test('dedupes by server id when REST and socket deliver the same row', () {
      final first = _msg(
        id: 'srv-1',
        text: 'hi',
        senderId: 'a',
        outingId: 'o1',
        sentAt: DateTime.utc(2026, 1, 1, 12),
      );
      final echo = _msg(
        id: 'srv-1',
        text: 'hi',
        senderId: 'a',
        outingId: 'o1',
        sentAt: DateTime.utc(2026, 1, 1, 12),
      );

      final merged = upsertOutingChatMessage([first], echo);
      expect(merged, hasLength(1));
      expect(merged.single.id, 'srv-1');
    });

    test('drops matching local_* pending when server message arrives', () {
      final pending = _msg(
        id: 'local_123',
        text: 'hello',
        senderId: 'me',
        outingId: 'o1',
        sentAt: DateTime.utc(2026, 1, 1, 12, 0, 1),
      );
      final server = _msg(
        id: 'srv-9',
        text: 'hello',
        senderId: 'me',
        outingId: 'o1',
        sentAt: DateTime.utc(2026, 1, 1, 12, 0, 2),
      );

      final merged = upsertOutingChatMessage([pending], server);
      expect(merged, hasLength(1));
      expect(merged.single.id, 'srv-9');
      expect(isLocalPendingMessageId(merged.single.id), isFalse);
    });

    test('orders by sentAt then id for rapid consecutive messages', () {
      final a = _msg(
        id: 'b',
        text: 'second',
        senderId: 'a',
        sentAt: DateTime.utc(2026, 1, 1, 12, 0, 1),
      );
      final b = _msg(
        id: 'a',
        text: 'first',
        senderId: 'a',
        sentAt: DateTime.utc(2026, 1, 1, 12, 0, 0),
      );
      final c = _msg(
        id: 'c',
        text: 'tie-break',
        senderId: 'a',
        sentAt: DateTime.utc(2026, 1, 1, 12, 0, 1),
      );

      var list = <ChatMessage>[];
      list = upsertOutingChatMessage(list, a);
      list = upsertOutingChatMessage(list, c);
      list = upsertOutingChatMessage(list, b);

      expect(list.map((m) => m.id).toList(), ['a', 'b', 'c']);
    });
  });
}
