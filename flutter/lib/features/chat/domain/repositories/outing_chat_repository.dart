import 'package:dartz/dartz.dart';
import 'package:yalla_5roga/core/error/failures.dart';
import 'package:yalla_5roga/features/chat/domain/entities/chat_message.dart';
import 'package:yalla_5roga/features/chat/domain/entities/outing_chat_read_result.dart';

abstract class OutingChatRepository {
  List<ChatMessage> cachedMessages(String outingId);

  Future<Either<Failure, List<ChatMessage>>> getMessages(
    String outingId, {
    bool forceRefresh = false,
  });

  Future<Either<Failure, ChatMessage>> getMessage(
    String outingId,
    String messageId,
  );

  bool hasOlderMessages(String outingId);
  Future<Either<Failure, List<ChatMessage>>> getOlderMessages(String outingId);

  Future<Either<Failure, ChatMessage>> sendMessage({
    required String outingId,
    required String text,
    required String senderId,
    required String senderName,
    String? avatar,
  });

  Future<Either<Failure, OutingChatReadResult>> markRead(String outingId);

  Future<Either<Failure, ChatMessage>> mutateMessage(
    String outingId,
    String messageId, {
    String? text,
  });
  Future<Either<Failure, ChatMessage>> retryMessage(ChatMessage message);

  Future<void> clearCache();
}
