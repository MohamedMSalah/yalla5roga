enum MessageDeliveryStatus { sent, delivered, seen }

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
    String? id,
    String? outingId,
    String? sender,
    String? text,
    String? time,
    bool? isMine,
    String? avatar,
    String? senderId,
    DateTime? sentAt,
    MessageDeliveryStatus? deliveryStatus,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      outingId: outingId ?? this.outingId,
      sender: sender ?? this.sender,
      text: text ?? this.text,
      time: time ?? this.time,
      isMine: isMine ?? this.isMine,
      avatar: avatar ?? this.avatar,
      senderId: senderId ?? this.senderId,
      sentAt: sentAt ?? this.sentAt,
      deliveryStatus: deliveryStatus ?? this.deliveryStatus,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'outingId': outingId,
    'sender': sender,
    'text': text,
    'time': time,
    'isMine': isMine,
    'avatar': avatar,
    'senderId': senderId,
    'sentAt': sentAt?.toIso8601String(),
    'deliveryStatus': deliveryStatus.name,
  };
}
