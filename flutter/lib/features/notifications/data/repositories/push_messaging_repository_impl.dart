import 'package:yalla_5roga/features/notifications/data/services/fcm_messaging_service.dart';
import 'package:yalla_5roga/features/notifications/domain/entities/push_authorization_status.dart';
import 'package:yalla_5roga/features/notifications/domain/entities/push_notification_payload.dart';
import 'package:yalla_5roga/features/notifications/domain/repositories/push_messaging_repository.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class PushMessagingRepositoryImpl implements PushMessagingRepository {
  PushMessagingRepositoryImpl({required this.messaging});

  final FcmMessagingService messaging;

  @override
  Future<void> initialize({
    required void Function(PushNotificationPayload) onOpened,
  }) {
    return messaging.initialize(onOpened: onOpened);
  }

  @override
  String? get token => messaging.token;

  @override
  Stream<String?> get tokenStream => messaging.tokenStream;

  @override
  Future<PushAuthorizationStatus> requestPermission() async {
    final status = await messaging.requestPermission();
    return switch (status) {
      AuthorizationStatus.authorized => PushAuthorizationStatus.authorized,
      AuthorizationStatus.provisional => PushAuthorizationStatus.provisional,
      AuthorizationStatus.denied => PushAuthorizationStatus.denied,
      _ => PushAuthorizationStatus.notDetermined,
    };
  }

  @override
  Future<String?> refreshToken() => messaging.refreshToken();

  @override
  Future<PushNotificationPayload?> takeInitialMessage() =>
      messaging.takeInitialMessage();
}
