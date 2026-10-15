import 'package:dartz/dartz.dart';
import 'package:yalla_5roga/core/error/failures.dart';
import 'package:yalla_5roga/features/outings/domain/entities/chat_message.dart';
import 'package:yalla_5roga/features/outings/domain/entities/outing_chat_read_result.dart';

abstract class OutingChatRepository {

  Future<Either<Failure, ChatMessage>> sendMessage({
    required String outingId,
    required String text,
    required String senderId,
    required String senderName,
  });

  Future<Either<Failure, OutingChatReadResult>> markRead(String outingId);
}
