import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:yalla_5roga/core/constants/app_constants.dart';
import 'package:yalla_5roga/features/notifications/domain/entities/push_notification_payload.dart';

typedef LocalNotificationTapCallback = void Function(
  PushNotificationPayload payload,
);

/// Shows system notifications while the app is in the foreground.
class LocalNotificationsService {
  LocalNotificationsService();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  final Set<String> _shownMessageIds = <String>{};
  var _initialized = false;
  LocalNotificationTapCallback? onNotificationTap;

  bool get isInitialized => _initialized;

  Future<void> initialize({LocalNotificationTapCallback? onTap}) async {
    if (_initialized) return;
    onNotificationTap = onTap;

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwin = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    try {
      final ok = await _plugin.initialize(
        settings: const InitializationSettings(android: android, iOS: darwin),
        onDidReceiveNotificationResponse: _onNotificationResponse,
      );
      if (ok == false) {
        debugPrint('[LocalNotifications] initialize returned false');
        return;
      }

      final androidPlugin = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      await androidPlugin?.createNotificationChannel(
        const AndroidNotificationChannel(
          AppConstants.fcmAndroidChannelId,
          AppConstants.fcmAndroidChannelName,
          description: AppConstants.fcmAndroidChannelDescription,
          importance: Importance.high,
        ),
      );

      _initialized = true;
    } catch (error, stack) {
      debugPrint('[LocalNotifications] initialize failed: $error\n$stack');
    }
  }

  Future<void> showFromPayload(PushNotificationPayload payload) async {
    if (!_initialized) return;
    if (!payload.hasDisplayContent) return;

    final dedupeKey =
        payload.deduplicationId ??
        '${payload.type}|${payload.title}|${payload.body}|${payload.outingId}|${payload.groupId}';
    if (_shownMessageIds.contains(dedupeKey)) return;
    _shownMessageIds.add(dedupeKey);
    if (_shownMessageIds.length > 100) {
      _shownMessageIds.remove(_shownMessageIds.first);
    }

    final title = payload.title?.trim().isNotEmpty == true
        ? payload.title!.trim()
        : AppConstants.appName;
    final body = payload.body?.trim() ?? '';

    try {
      await _plugin.show(
        id: dedupeKey.hashCode,
        title: title,
        body: body,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            AppConstants.fcmAndroidChannelId,
            AppConstants.fcmAndroidChannelName,
            channelDescription: AppConstants.fcmAndroidChannelDescription,
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        payload: jsonEncode(payload.toLocalPayloadMap()),
      );
    } catch (error, stack) {
      debugPrint('[LocalNotifications] show failed: $error\n$stack');
    }
  }

  Future<PushNotificationPayload?> takeInitialMessage() async {
    if (!_initialized) return null;
    final details = await _plugin.getNotificationAppLaunchDetails();
    return details?.didNotificationLaunchApp == true
        ? _decode(details?.notificationResponse?.payload)
        : null;
  }

  void _onNotificationResponse(NotificationResponse response) {
    final payload = _decode(response.payload);
    if (payload != null) onNotificationTap?.call(payload);
  }

  PushNotificationPayload? _decode(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return PushNotificationPayload.fromLocalData(decoded);
      }
    } catch (error) {
      debugPrint('[LocalNotifications] tap parse failed: $error');
    }
    return null;
  }
}
