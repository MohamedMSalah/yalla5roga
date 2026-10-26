import 'package:yalla_5roga/core/network/api_payload.dart';
import 'package:yalla_5roga/features/outings/domain/entities/outing_chat_read_result.dart';

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
    return OutingChatReadResultModel(
      outingId: apiString(json['outingId']) ?? outingId,
      unreadCount: apiInt(json['unreadCount']),
      unreadChatCount: apiInt(json['unreadChatCount']),
    );
  }
}
