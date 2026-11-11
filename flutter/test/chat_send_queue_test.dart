import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yalla_5roga/core/error/exceptions.dart';
import 'package:yalla_5roga/features/chat/data/datasources/chat_send_queue.dart';
import 'package:yalla_5roga/features/chat/domain/entities/chat_message.dart';
import 'package:yalla_5roga/features/chat/domain/outing_chat_message_merge.dart';

ChatMessage pending(String key) => ChatMessage(
  id: 'local_$key',
  clientMessageId: key,
  outingId: 'outing',
  sender: 'Alice',
  senderId: 'alice',
  text: key,
  time: '',
  isMine: true,
  sentAt: DateTime(2026, 1, key == 'first' ? 1 : 2),
  deliveryStatus: MessageDeliveryStatus.pending,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SharedPreferences prefs;
  String? uid;
  ChatSendQueue queue() => ChatSendQueue(prefs, () => uid, 'backend');

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    uid = 'alice';
  });

  test(
    'offline enqueue survives restart and retries the same UUID once',
    () async {
      await queue().add(pending('first'));
      final restored = queue();
      final committed = <String, ChatMessage>{};
      final calls = <String>[];
      final result = restored.updates.first;
      final reply = Completer<ChatMessage>();
      Future<ChatMessage> send(ChatMessage message) async {
        final key = message.clientMessageId!;
        calls.add(key);
        committed.putIfAbsent(
          key,
          () => message.copyWith(
            id: 'server-id',
            deliveryStatus: MessageDeliveryStatus.sent,
          ),
        );
        if (calls.length == 1) throw const NetworkException();
        return reply.future;
      }

      expect(await restored.flush(send), true);
      expect(restored.hasPending, true);
      final first = restored.flush(send);
      final concurrent = restored.flush(send);
      expect(identical(first, concurrent), true);
      reply.complete(committed.values.single);
      expect(await first, false);
      expect((await result).id, 'server-id');
      expect(restored.hasPending, false);
      expect(calls, ['first', 'first']);
      expect(committed.length, 1);
    },
  );

  test(
    'a closed chat fails permanently and does not block the next send',
    () async {
      final outbox = queue();
      await outbox.add(pending('first'));
      await outbox.add(pending('second'));
      final changes = outbox.updates.take(2).toList();
      expect(
        await outbox.flush((message) async {
          if (message.clientMessageId == 'first') {
            throw const ServerException('CHAT_CLOSED', 'CONFLICT', 409);
          }
          return message.copyWith(
            id: 'server',
            deliveryStatus: MessageDeliveryStatus.sent,
          );
        }),
        false,
      );
      expect((await changes).map((item) => item.deliveryStatus), [
        MessageDeliveryStatus.failed,
        MessageDeliveryStatus.sent,
      ]);
      expect(
        queue().messages.single.deliveryStatus,
        MessageDeliveryStatus.failed,
      );
      uid = 'bob';
      expect(queue().messages, isEmpty);
    },
  );

  test('a delayed local record cannot replace a canonical socket echo', () {
    final local = pending('first');
    final canonical = local.copyWith(
      id: 'server',
      deliveryStatus: MessageDeliveryStatus.sent,
    );
    expect(upsertOutingChatMessage([canonical], local), [canonical]);
    expect(upsertOutingChatMessage([local], canonical), [canonical]);
  });

  test('logout during a send cannot publish an old account response', () async {
    final outbox = queue();
    await outbox.add(pending('first'));
    final reply = Completer<ChatMessage>();
    final updates = <ChatMessage>[];
    final sub = outbox.updates.listen(updates.add);
    final drain = outbox.flush((_) => reply.future);
    uid = 'bob';
    await outbox.clear('alice');
    reply.complete(pending('first').copyWith(id: 'server'));
    expect(await drain, false);
    expect(updates, isEmpty);
    uid = 'alice';
    expect(queue().messages, isEmpty);
    await sub.cancel();
  });
}
