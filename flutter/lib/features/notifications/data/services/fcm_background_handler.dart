import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:yalla_5roga/firebase_options.dart';
import 'package:yalla_5roga/features/notifications/data/services/notification_background_runtime.dart';
import 'package:yalla_5roga/features/notifications/domain/entities/push_notification_payload.dart';

/// Top-level background handler required by [FirebaseMessaging.onBackgroundMessage].
///
/// Keep this minimal. Do not navigate or touch UI here.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
    if (defaultTargetPlatform == TargetPlatform.android &&
        message.notification == null) {
      final runtime = await NotificationBackgroundRuntime.create();
      try {
        await runtime.local.showFromPayload(
          PushNotificationPayload.fromRemoteMessage(message),
        );
      } finally {
        runtime.client.dio.close();
      }
    }
    if (kDebugMode) {
      debugPrint(
        '[FCM][background] id=${message.messageId} '
        'type=${message.data['type']} '
        'title=${message.notification?.title}',
      );
    }
  } catch (error, stack) {
    debugPrint('[FCM][background] handler error: $error\n$stack');
  }
}
