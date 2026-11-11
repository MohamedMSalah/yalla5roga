import 'package:firebase_messaging/firebase_messaging.dart';

enum NotificationDestination {
  group,
  groupMembers,
  outing,
  placeVoting,
  attendance,
  chat,
  inbox,
}

class PushNotificationPayload {
  PushNotificationPayload.fromData(Map<String, dynamic> data)
    : type = _type(data),
      outingId =
          _pick(data, 'outingId') ??
          _pick(data, 'outing_id') ??
          _pick(data, 'chatId') ??
          _pick(data, 'eventId'),
      groupId = _pick(data, 'groupId') ?? _pick(data, 'group_id'),
      messageId = _pick(data, 'messageId'),
      pushId = _pick(data, 'pushId'),
      notificationId = _pick(data, 'notificationId'),
      recipientUserId = _pick(data, 'recipientUserId'),
      title = _pick(data, 'title'),
      body = _pick(data, 'body');

  factory PushNotificationPayload.fromRemoteMessage(RemoteMessage message) =>
      PushNotificationPayload.fromData({
        ...message.data,
        'pushId': message.data['pushId'] ?? message.messageId,
        'title': message.notification?.title ?? message.data['title'],
        'body': message.notification?.body ?? message.data['body'],
      });

  factory PushNotificationPayload.fromLocalData(Map<String, dynamic> data) {
    // Older local notifications stored the Firebase transport ID here.
    if (data['pushId'] == null &&
        data['notificationId'] == null &&
        data['messageId'] != null &&
        data['type'] != 'chat_message') {
      return PushNotificationPayload.fromData({
        ...data,
        'pushId': data['messageId'],
        'messageId': null,
      });
    }
    return PushNotificationPayload.fromData(data);
  }

  final String type;
  final String? outingId;
  final String? groupId;
  final String? messageId;
  final String? pushId;
  final String? notificationId;
  final String? recipientUserId;
  final String? title;
  final String? body;

  String? get deduplicationId => notificationId ?? pushId;

  NotificationDestination get destination => switch (type) {
    'chat' || 'chat_message' => NotificationDestination.chat,
    'place_vote' ||
    'vote' ||
    'voting_closed_early' ||
    'voting_deadline_reached' ||
    'winner_selected' ||
    'tie_break_selected' => NotificationDestination.placeVoting,
    'attendance_vote' ||
    'attendance_changed' => NotificationDestination.attendance,
    'member_joined' || 'member_left' => NotificationDestination.groupMembers,
    'group' ||
    'group_created' ||
    'group_updated' ||
    'group_invite' => NotificationDestination.group,
    'outing' ||
    'outing_created' ||
    'outing_updated' ||
    'outing_invite' ||
    'outing_reminder' ||
    'outing_confirmed' ||
    'outing_cancelled' => NotificationDestination.outing,
    _ when outingId != null => NotificationDestination.outing,
    _ when groupId != null => NotificationDestination.group,
    _ => NotificationDestination.inbox,
  };

  bool get hasDisplayContent => title != null || body != null;

  Map<String, String> toLocalPayloadMap() => {
    'type': type,
    'outingId': ?outingId,
    'groupId': ?groupId,
    'messageId': ?messageId,
    'pushId': ?pushId,
    'notificationId': ?notificationId,
    'recipientUserId': ?recipientUserId,
    'title': ?title,
    'body': ?body,
  };

  static String _type(Map<String, dynamic> data) {
    final type = _pick(data, 'type')?.toLowerCase();
    if (type != null && type != 'unknown') return type;
    return _pick(data, 'notification_type')?.toLowerCase() ?? '';
  }

  static String? _pick(Map<String, dynamic> data, String key) {
    final value = data[key];
    if (value is! String || value.trim().isEmpty) return null;
    return value.trim();
  }
}
