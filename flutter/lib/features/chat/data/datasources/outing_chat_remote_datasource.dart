import 'package:dio/dio.dart';
import 'package:yalla_5roga/core/constants/api_constants.dart';
import 'package:yalla_5roga/core/error/exceptions.dart';
import 'package:yalla_5roga/core/network/api_client.dart';
import 'package:yalla_5roga/core/network/api_payload.dart';
import 'package:yalla_5roga/core/network/dio_interceptors.dart';
import 'package:yalla_5roga/features/chat/data/models/chat_message_model.dart';
import 'package:yalla_5roga/features/chat/data/models/outing_chat_read_result_model.dart';
import 'package:yalla_5roga/features/chat/domain/entities/chat_message.dart';
import 'package:yalla_5roga/features/chat/domain/entities/outing_chat_read_result.dart';

abstract class OutingChatDataSource {
  Future<({List<ChatMessage> messages, String? nextCursor})> getMessages(
    String outingId, {
    String? before,
    String? messageId,
  });
  Future<ChatMessage> sendMessage({
    required String outingId,
    required String text,
    required String senderId,
    required String senderName,
    required String clientMessageId,
  });
  Future<OutingChatReadResult> markRead(String outingId);
}

class OutingChatRemoteDataSourceImpl implements OutingChatDataSource {
  const OutingChatRemoteDataSourceImpl(this._client);

  final ApiClient _client;

  @override
  Future<({List<ChatMessage> messages, String? nextCursor})> getMessages(
    String outingId, {
    String? before,
    String? messageId,
  }) async {
    try {
      final response = await _client.get<Map<String, dynamic>>(
        ApiConstants.outingChatMessages(outingId),
        queryParameters: messageId == null
            ? {'limit': 40, 'before': ?before}
            : {'messageId': messageId},
      );
      final items = apiObjectList(
        response.data,
        aliases: const ['messages', 'items'],
      );
      return (
        messages: [
          for (final item in items)
            ChatMessageModel.fromJson(item, outingId: outingId),
        ],
        nextCursor: apiString(response.data?['next_cursor']),
      );
    } on DioException catch (error) {
      throw _unwrap(error);
    }
  }

  @override
  Future<ChatMessage> sendMessage({
    required String outingId,
    required String text,
    required String senderId,
    required String senderName,
    required String clientMessageId,
  }) async {
    try {
      final response = await _client.post<Map<String, dynamic>>(
        ApiConstants.outingChatMessages(outingId),
        data: {'text': text, 'clientMessageId': clientMessageId},
        options: Options(extra: {expectedUserIdKey: senderId}),
      );
      final payload = apiPayload(response.data);
      return ChatMessageModel.fromJson(payload, outingId: outingId).copyWith(
        sender: senderName,
        text: apiString(payload['text']) ?? text,
        isMine: true,
        senderId:
            apiString(payload['sender_id']) ??
            apiString(payload['senderId']) ??
            senderId,
        sentAt:
            DateTime.tryParse(
              apiString(payload['sent_at']) ??
                  apiString(payload['sentAt']) ??
                  '',
            ) ??
            DateTime.now(),
      );
    } on DioException catch (error) {
      throw _unwrap(error);
    }
  }

  @override
  Future<OutingChatReadResult> markRead(String outingId) async {
    try {
      final response = await _client.patch<Map<String, dynamic>>(
        ApiConstants.outingChatRead(outingId),
      );
      final payload = apiPayload(response.data);
      return OutingChatReadResultModel.fromJson(payload, outingId: outingId);
    } on DioException catch (error) {
      throw _unwrap(error);
    }
  }

  AppException _unwrap(DioException error) {
    if (error.error is AppException) return error.error as AppException;
    return ServerException(error.message ?? 'Server error');
  }
}
