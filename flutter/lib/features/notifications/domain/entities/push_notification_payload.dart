import 'package:firebase_messaging/firebase_messaging.dart';

enum NotificationDestination {
  group,
  groupMembers,
  outing,
  placeVoting,
  attendance,
  chat,
  inbox,
  invitation,
}

enum NotificationActionType { accept, decline, reply, markRead }

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
      invitationId = _pick(data, 'invitationId'),
      pushId = _pick(data, 'pushId'),
      notificationId = _pick(data, 'notificationId'),
      recipientUserId = _pick(data, 'recipientUserId'),
      title = _pick(data, 'title'),
      body = _pick(data, 'body'),
      actionType = _parseActionType(_pick(data, 'actionType')),
      replyText = _pick(data, 'replyText');

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
  final String? invitationId;
  final String? pushId;
  final String? notificationId;
  final String? recipientUserId;
  final String? title;
  final String? body;
  final NotificationActionType? actionType;
  final String? replyText;

  String? get deduplicationId => notificationId ?? pushId;

  bool get isInteractiveAction => actionType != null;

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
    'member_joined' || 'member_left' => NotificationDestination.group,
    'group' ||
    'group_created' ||
    'group_updated' => NotificationDestination.group,
    'invitation' when outingId != null => NotificationDestination.invitation,
    'group_invite' || 'invitation' => NotificationDestination.invitation,
    'outing' ||
    'outing_created' ||
    'outing_updated' ||
    'outing_reminder' ||
    'outing_confirmed' ||
    'outing_cancelled' => NotificationDestination.outing,
    'outing_invite' => NotificationDestination.invitation,
    _ when outingId != null => NotificationDestination.outing,
    _ when groupId != null => NotificationDestination.group,
    _ => NotificationDestination.inbox,
  };

  bool get hasDisplayContent => title != null || body != null;

  Map<String, String> toLocalPayloadMap() {
    final map = <String, String>{'type': type};
    if (outingId != null) map['outingId'] = outingId!;
    if (groupId != null) map['groupId'] = groupId!;
    if (messageId != null) map['messageId'] = messageId!;
    if (invitationId != null) map['invitationId'] = invitationId!;
    if (pushId != null) map['pushId'] = pushId!;
    if (notificationId != null) map['notificationId'] = notificationId!;
    if (recipientUserId != null) map['recipientUserId'] = recipientUserId!;
    if (title != null) map['title'] = title!;
    if (body != null) map['body'] = body!;
    return map;
  }

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

  static NotificationActionType? _parseActionType(String? value) {
    if (value == null) return null;
    return switch (value.toLowerCase()) {
      'accept' => NotificationActionType.accept,
      'decline' => NotificationActionType.decline,
      'reply' => NotificationActionType.reply,
      'mark_read' || 'markread' => NotificationActionType.markRead,
      _ => null,
    };
  }
}
