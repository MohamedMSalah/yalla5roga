enum MessageDeliveryStatus { pending, failed, sent, delivered, seen }

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
    this.clientMessageId,
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
  final String? clientMessageId;
  final DateTime? sentAt;
  final MessageDeliveryStatus deliveryStatus;

  DateTime? get editDeadline => sentAt?.add(const Duration(minutes: 1));

  bool canEditAt(DateTime now) =>
      text.isNotEmpty &&
      !id.startsWith('local_') &&
      editDeadline?.isAfter(now) == true;

  ChatMessage copyWith({
    String? id,
    String? outingId,
    String? sender,
    String? text,
    String? time,
    bool? isMine,
    String? avatar,
    String? senderId,
    String? clientMessageId,
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
      clientMessageId: clientMessageId ?? this.clientMessageId,
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
    'clientMessageId': clientMessageId,
    'sentAt': sentAt?.toIso8601String(),
    'deliveryStatus': deliveryStatus.name,
  };
}
