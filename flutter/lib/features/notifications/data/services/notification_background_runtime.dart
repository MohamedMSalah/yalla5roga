import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:yalla_5roga/core/config/app_config.dart';
import 'package:yalla_5roga/core/network/api_client.dart';
import 'package:yalla_5roga/core/network/dio_interceptors.dart';
import 'package:yalla_5roga/firebase_options.dart';
import 'package:yalla_5roga/features/notifications/data/services/interactive_notification_handler.dart';
import 'package:yalla_5roga/features/notifications/data/services/local_notifications_service.dart';
import 'package:yalla_5roga/features/notifications/data/services/notification_action_dispatcher.dart';

class NotificationBackgroundRuntime {
  NotificationBackgroundRuntime._(this.local, this.client, this.actions);
  final LocalNotificationsService local;
  final ApiClient client;
  final NotificationActionDispatcher actions;

  static Future<NotificationBackgroundRuntime> create() async {
    if (Firebase.apps.isEmpty)
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    final auth = FirebaseAuth.instance;
    await auth.authStateChanges().first.timeout(const Duration(seconds: 5));
    final config = AppConfig.fromEnvironment();
    final dio = Dio(
      BaseOptions(
        baseUrl: config.apiBaseUrl,
        connectTimeout: const Duration(seconds: 8),
        receiveTimeout: const Duration(seconds: 10),
        sendTimeout: const Duration(seconds: 8),
      ),
    );
    final interceptor = AuthInterceptor(
      currentUserId: () => auth.currentUser?.uid,
      tokenProvider: ({bool forceRefresh = false}) async =>
          auth.currentUser?.getIdToken(forceRefresh),
    );
    interceptor.bind(dio);
    dio.interceptors.addAll([interceptor, ErrorInterceptor()]);
    final client = ApiClient(dio);
    final local = LocalNotificationsService(
      client: client,
      currentUserId: () => auth.currentUser?.uid,
    );
    await local.initialize();
    final actions = NotificationActionDispatcher(
      handler: InteractiveNotificationHandler(client),
      currentUserId: () => auth.currentUser?.uid,
      onSuccess: local.completeAction,
      onFailure: local.showActionFailure,
    );
    return NotificationBackgroundRuntime._(local, client, actions);
  }
}

@pragma('vm:entry-point')
Future<void> notificationActionBackgroundHandler(
  NotificationResponse response,
) async {
  final runtime = await NotificationBackgroundRuntime.create();
  try {
    final payload = LocalNotificationsService.decodeResponse(response);
    if (payload != null) await runtime.actions.dispatch(payload);
  } finally {
    runtime.client.dio.close();
  }
}
