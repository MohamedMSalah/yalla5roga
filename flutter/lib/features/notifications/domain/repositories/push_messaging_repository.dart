import 'package:yalla_5roga/features/notifications/domain/entities/push_authorization_status.dart';
import 'package:yalla_5roga/features/notifications/domain/entities/push_notification_payload.dart';

/// Abstraction over FCM + local notification display.
abstract class PushMessagingRepository {
  Future<void> initialize({
    required void Function(PushNotificationPayload) onOpened,
  });

  String? get token;

  Stream<String?> get tokenStream;

  Future<PushAuthorizationStatus> requestPermission();

  Future<String?> refreshToken();

  Future<PushNotificationPayload?> takeInitialMessage();
}
