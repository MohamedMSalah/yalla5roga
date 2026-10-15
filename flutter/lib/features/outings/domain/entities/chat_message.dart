import 'package:yalla_5roga/features/outings/domain/entities/outing_enums.dart';

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.sender,
    required this.text,
    required this.time,
    required this.isMine,
    this.outingId,
    this.avatar,
    this.senderId,
    this.sentAt,
    this.deliveryStatus = MessageDeliveryStatus.sent,
  });

  final String id;
  final String? outingId;
  final String sender;
  final String text;

  /// Display time string (or format [sentAt] in UI when available).
  final String time;
  final bool isMine;
  final String? avatar;
  final String? senderId;
  final DateTime? sentAt;
  final MessageDeliveryStatus deliveryStatus;

  ChatMessage copyWith({
    MessageDeliveryStatus? deliveryStatus,
    String? outingId,
    DateTime? sentAt,
  }) {
    return ChatMessage(
      id: id,
      outingId: outingId ?? this.outingId,
      sender: sender,
      text: text,
      time: time,
      isMine: isMine,
      avatar: avatar,
      senderId: senderId,
      sentAt: sentAt ?? this.sentAt,
      deliveryStatus: deliveryStatus ?? this.deliveryStatus,
    );
  }
}
