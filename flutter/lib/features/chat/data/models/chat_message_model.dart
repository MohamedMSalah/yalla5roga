import 'package:yalla_5roga/core/network/api_payload.dart';
import 'package:yalla_5roga/features/chat/domain/entities/chat_message.dart';

class ChatMessageModel extends ChatMessage {
  const ChatMessageModel({
    required super.id,
    required super.sender,
    required super.text,
    required super.time,
    required super.isMine,
    super.outingId,
    super.avatar,
    super.senderId,
    super.clientMessageId,
    super.sentAt,
    super.deliveryStatus,
  });

  factory ChatMessageModel.fromEntity(ChatMessage message) {
    return ChatMessageModel(
      id: message.id,
      outingId: message.outingId,
      sender: message.sender,
      text: message.text,
      time: message.time,
      isMine: message.isMine,
      avatar: message.avatar,
      senderId: message.senderId,
      clientMessageId: message.clientMessageId,
      sentAt: message.sentAt,
      deliveryStatus: message.deliveryStatus,
    );
  }

  factory ChatMessageModel.fromJson(
    Map<dynamic, dynamic> json, {
    String? outingId,
  }) {
    final sentAtRaw =
        apiString(json['sent_at']) ??
        apiString(json['sentAt']) ??
        apiString(json['createdAt']);
    return ChatMessageModel(
      id: apiString(json['id']) ?? '',
      outingId:
          apiString(json['outing_id']) ??
          apiString(json['outingId']) ??
          outingId,
      sender: apiString(json['sender']) ?? '',
      text: apiString(json['text']) ?? '',
      time: apiString(json['time']) ?? '',
      isMine: apiBool(json['isMine']),
      avatar: apiString(json['avatar']),
      senderId: apiString(json['sender_id']) ?? apiString(json['senderId']),
      clientMessageId:
          apiString(json['client_message_id']) ??
          apiString(json['clientMessageId']),
      sentAt: DateTime.tryParse(sentAtRaw ?? ''),
      deliveryStatus: MessageDeliveryStatus.values.firstWhere(
        (status) =>
            status.name ==
            (apiString(json['delivery_status']) ??
                apiString(json['deliveryStatus'])),
        orElse: () => MessageDeliveryStatus.sent,
      ),
    );
  }
}
