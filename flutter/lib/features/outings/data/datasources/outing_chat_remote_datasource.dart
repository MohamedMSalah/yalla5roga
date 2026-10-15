import 'package:dio/dio.dart';
import 'package:yalla_5roga/core/constants/api_constants.dart';
import 'package:yalla_5roga/core/error/exceptions.dart';
import 'package:yalla_5roga/core/network/api_client.dart';
import 'package:yalla_5roga/core/network/api_payload.dart';
import 'package:yalla_5roga/features/outings/data/models/outing_chat_read_result_model.dart';
import 'package:yalla_5roga/features/outings/domain/entities/chat_message.dart';
import 'package:yalla_5roga/features/outings/domain/entities/outing_chat_read_result.dart';

abstract class OutingChatDataSource {
  Future<List<ChatMessage>> getMessages(String outingId);
  Future<ChatMessage> sendMessage({
    required String outingId,
    required String text,
    required String senderId,
    required String senderName,
  });
  Future<OutingChatReadResult> markRead(String outingId);
}

class OutingChatRemoteDataSourceImpl implements OutingChatDataSource {
  const OutingChatRemoteDataSourceImpl(this._client);

  final ApiClient _client;

  @override
  Future<List<ChatMessage>> getMessages(String outingId) async {
    try {
      final response = await _client.get<Map<String, dynamic>>(
        ApiConstants.outingChatMessages(outingId),
      );
      final payload = apiPayload(response.data);
      final raw = payload['items'] ?? payload['messages'] ?? payload;
      if (raw is! List) return const [];
      return [
        for (final item in raw)
          if (item is Map)
            ChatMessage(
              id: apiString(item['id']) ?? '',
              outingId: outingId,
              sender: apiString(item['sender']) ?? '',
              text: apiString(item['text']) ?? '',
              time: apiString(item['time']) ?? '',
              isMine: apiBool(item['isMine']),
              avatar: apiString(item['avatar']),
              senderId: apiString(item['senderId']),
              sentAt: DateTime.tryParse(apiString(item['sentAt']) ?? ''),
            ),
      ];
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
  }) async {
    try {
      final response = await _client.post<Map<String, dynamic>>(
        ApiConstants.outingChatMessages(outingId),
        data: {'text': text, 'senderId': senderId, 'sender': senderName},
      );
      final payload = apiPayload(response.data);
      return ChatMessage(
        id: apiString(payload['id']) ?? '',
        outingId: outingId,
        sender: apiString(payload['sender']) ?? senderName,
        text: apiString(payload['text']) ?? text,
        time: apiString(payload['time']) ?? '',
        isMine: true,
        senderId: senderId,
        sentAt:
            DateTime.tryParse(apiString(payload['sentAt']) ?? '') ??
            DateTime.now(),
      );
    } on DioException catch (error) {
      throw _unwrap(error);
    }
  }

  @override
  Future<OutingChatReadResult> markRead(String outingId) async {
    try {
      final response = await _client.post<Map<String, dynamic>>(
        ApiConstants.outingChatRead(outingId),
      );
      return OutingChatReadResultModel.fromJson(
        apiPayload(response.data),
        outingId: outingId,
      );
    } on DioException catch (error) {
      throw _unwrap(error);
    }
  }

  AppException _unwrap(DioException error) {
    if (error.error is AppException) return error.error as AppException;
    return ServerException(error.message ?? 'Server error');
  }
}
