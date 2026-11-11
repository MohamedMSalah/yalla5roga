import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yalla_5roga/features/notifications/domain/entities/push_notification_payload.dart';

void main() {
  const destinations = {
    'group_created': NotificationDestination.group,
    'group_updated': NotificationDestination.group,
    'outing_created': NotificationDestination.outing,
    'outing_updated': NotificationDestination.outing,
    'chat_message': NotificationDestination.chat,
    'place_vote': NotificationDestination.placeVoting,
    'attendance_vote': NotificationDestination.attendance,
    'attendance_changed': NotificationDestination.attendance,
    'member_joined': NotificationDestination.groupMembers,
    'member_left': NotificationDestination.groupMembers,
    'outing_reminder': NotificationDestination.outing,
    'outing_invite': NotificationDestination.outing,
    'group_invite': NotificationDestination.group,
    'winner_selected': NotificationDestination.placeVoting,
  };
  for (final entry in destinations.entries) {
    test('${entry.key} retains its destination in Firebase and local taps', () {
      final remote = PushNotificationPayload.fromRemoteMessage(
        RemoteMessage(
          messageId: 'fcm-transport-id',
          data: {
            'type': entry.key,
            'pushId': 'outbox-id',
            'notificationId': 'inbox-id',
            'recipientUserId': 'recipient',
            'groupId': 'group-id',
            'outingId': 'outing-id',
            if (entry.key == 'chat_message') 'messageId': 'chat-message-id',
          },
        ),
      );
      final local = PushNotificationPayload.fromLocalData(
        remote.toLocalPayloadMap(),
      );
      expect(remote.destination, entry.value);
      expect(local.destination, entry.value);
      expect(local.groupId, 'group-id');
      expect(local.outingId, 'outing-id');
      expect(local.recipientUserId, 'recipient');
      expect(local.deduplicationId, 'inbox-id');
      expect(local.pushId, 'outbox-id');
      expect(
        local.messageId,
        entry.key == 'chat_message' ? 'chat-message-id' : null,
      );
    });
  }

  test('legacy push uses snake case and separates transport from chat ID', () {
    final payload = PushNotificationPayload.fromRemoteMessage(
      const RemoteMessage(
        messageId: 'transport-id',
        data: {'notification_type': 'chat', 'outing_id': 'legacy-outing'},
      ),
    );
    expect(payload.destination, NotificationDestination.chat);
    expect(payload.outingId, 'legacy-outing');
    expect(payload.messageId, isNull);
    expect(payload.deduplicationId, 'transport-id');
  });

  test('legacy local tap reads the category and recovers the transport ID', () {
    final payload = PushNotificationPayload.fromLocalData({
      'type': 'unknown',
      'notification_type': 'chat',
      'outing_id': 'legacy-outing',
      'messageId': 'old-transport-id',
    });
    expect(payload.destination, NotificationDestination.chat);
    expect(payload.outingId, 'legacy-outing');
    expect(payload.messageId, isNull);
    expect(payload.deduplicationId, 'old-transport-id');
  });

  test('a deleted outing target does not fall back to its group', () {
    final payload = PushNotificationPayload.fromData({
      'type': 'outing_updated',
      'groupId': 'group-id',
    });
    expect(payload.destination, NotificationDestination.outing);
    expect(payload.outingId, isNull);
  });
}
