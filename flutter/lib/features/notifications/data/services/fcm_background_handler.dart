import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:yalla_5roga/firebase_options.dart';

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
