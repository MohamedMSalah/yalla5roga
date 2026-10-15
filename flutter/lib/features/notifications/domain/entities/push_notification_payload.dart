import 'package:equatable/equatable.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

/// Known push categories. Unknown values map to [PushNotificationType.unknown].
enum PushNotificationType {
  outing,
  group,
  chat,
  vote,
  invitation,
  system,
  unknown;

  static PushNotificationType fromData(String? raw) {
    switch (raw?.trim().toLowerCase()) {
      case 'outing':
        return PushNotificationType.outing;
      case 'group':
        return PushNotificationType.group;
      case 'chat':
        return PushNotificationType.chat;
      case 'vote':
        return PushNotificationType.vote;
      case 'invitation':
      case 'invite':
        return PushNotificationType.invitation;
      case 'system':
        return PushNotificationType.system;
      default:
        return PushNotificationType.unknown;
    }
  }
}

/// Normalized FCM payload for navigation and local display.
///
/// Expected `data` keys (all optional except useful routing fields):
/// `type`, `outingId`, `groupId`, `chatId`, and any future keys in [data].
class PushNotificationPayload extends Equatable {
  const PushNotificationPayload({
    required this.type,
    required this.data,
    this.messageId,
    this.title,
    this.body,
    this.outingId,
    this.groupId,
    this.chatId,
  });

  final String? messageId;
  final String? title;
  final String? body;
  final PushNotificationType type;
  final String? outingId;
  final String? groupId;
  final String? chatId;
  final Map<String, String> data;

  bool get hasDisplayContent =>
      (title != null && title!.trim().isNotEmpty) ||
      (body != null && body!.trim().isNotEmpty);

  factory PushNotificationPayload.fromRemoteMessage(RemoteMessage message) {
    final data = <String, String>{
      for (final entry in message.data.entries) entry.key: '${entry.value}',
    };

    String? pick(String key) {
      final value = data[key]?.trim();
      if (value == null || value.isEmpty) return null;
      return value;
    }

    return PushNotificationPayload(
      messageId: message.messageId,
      title: message.notification?.title ?? pick('title'),
      body: message.notification?.body ?? pick('body'),
      type: PushNotificationType.fromData(pick('type')),
      outingId: pick('outingId') ?? pick('eventId'),
      groupId: pick('groupId'),
      chatId: pick('chatId') ?? pick('outingId'),
      data: data,
    );
  }

  /// Reconstruct from local-notification payload JSON-ish map encoding.
  factory PushNotificationPayload.fromLocalPayload(Map<String, dynamic> map) {
    final data = <String, String>{
      for (final entry in map.entries)
        if (entry.key != 'title' &&
            entry.key != 'body' &&
            entry.key != 'messageId')
          entry.key: entry.value?.toString() ?? '',
    };

    String? pick(String key) {
      final value = (map[key] ?? data[key])?.toString().trim();
      if (value == null || value.isEmpty) return null;
      return value;
    }

    return PushNotificationPayload(
      messageId: pick('messageId'),
      title: pick('title'),
      body: pick('body'),
      type: PushNotificationType.fromData(pick('type')),
      outingId: pick('outingId') ?? pick('eventId'),
      groupId: pick('groupId'),
      chatId: pick('chatId') ?? pick('outingId'),
      data: data,
    );
  }

  Map<String, dynamic> toLocalPayloadMap() => {
    if (messageId != null) 'messageId': messageId,
    if (title != null) 'title': title,
    if (body != null) 'body': body,
    'type': type.name,
    if (outingId != null) 'outingId': outingId,
    if (groupId != null) 'groupId': groupId,
    if (chatId != null) 'chatId': chatId,
    ...data,
  };

  @override
  List<Object?> get props => [
    messageId,
    title,
    body,
    type,
    outingId,
    groupId,
    chatId,
    data,
  ];
}
