import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:yalla_5roga/core/constants/app_constants.dart';
import 'package:yalla_5roga/features/notifications/domain/entities/push_notification_payload.dart';

typedef LocalNotificationTapCallback = void Function(
  PushNotificationPayload payload,
);

/// Notification action IDs used in interactive notifications.
abstract class NotificationActionIds {
  static const String accept = 'accept_action';
  static const String decline = 'decline_action';
  static const String reply = 'reply_action';
  static const String markRead = 'mark_read_action';
}

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

      // Request iOS permissions for notifications.
      try {
        await _plugin
            .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin
            >()
            ?.requestPermissions(
              alert: true,
              badge: true,
              sound: true,
            );
      } catch (error) {
        debugPrint('[LocalNotifications] iOS permissions failed: $error');
      }

      _initialized = true;
    } catch (error, stack) {
      debugPrint('[LocalNotifications] initialize failed: $error\n$stack');
    }
  }

  /// Builds the list of Android notification actions based on notification type.
  List<AndroidNotificationAction> _buildAndroidActions(String type) {
    return switch (type) {
      'group_invite' || 'invitation' => [
          const AndroidNotificationAction(
            NotificationActionIds.accept,
            'Accept',
          ),
          const AndroidNotificationAction(
            NotificationActionIds.decline,
            'Decline',
          ),
        ],
      'chat' || 'chat_message' => [
          const AndroidNotificationAction(
            NotificationActionIds.reply,
            'Reply',
          ),
          const AndroidNotificationAction(
            NotificationActionIds.markRead,
            'Mark as Read',
          ),
        ],
      _ => [],
    };
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

    final androidActions = _buildAndroidActions(payload.type);

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
            actions: androidActions,
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
    if (details?.didNotificationLaunchApp != true) return null;
    return _decodeFromResponse(details!.notificationResponse!);
  }

  void _onNotificationResponse(NotificationResponse response) {
    final payload = _decodeFromResponse(response);
    if (payload != null) onNotificationTap?.call(payload);
  }

  PushNotificationPayload? _decodeFromResponse(NotificationResponse response) {
    // First, decode the base payload.
    final payload = _decode(response.payload);

    // Check if this was an action tap (not just notification body tap).
    // actionId will be non-null for action button taps.
    final actionId = response.actionId;

    // For default body tap, actionId might be null or a platform-specific value.
    // We treat null/empty actionId as a body tap.
    if (actionId == null || actionId.isEmpty) {
      return payload;
    }

    // This was an action button tap. Map actionId to actionType.
    final actionType = _mapActionIdToType(actionId);
    if (actionType == null) {
      // Unknown action, treat as body tap.
      return payload;
    }

    // For reply action, try to extract the text from response inputs.
    String? replyText;
    if (actionType == NotificationActionType.reply) {
      // The reply text is typically available in the response's input field.
      // For Android with showsUserInterface=true, the text is in response.input?.
      replyText = response.input?.trim();
    }

    if (payload != null) {
      // Create a new payload with action information.
      return PushNotificationPayload.fromData({
        ...payload.toLocalPayloadMap(),
        'actionType': _actionTypeToString(actionType),
        if (replyText != null && replyText.isNotEmpty) 'replyText': replyText,
      });
    } else {
      // If payload is null but we have an action, create a minimal payload.
      return PushNotificationPayload.fromData({
        'actionType': _actionTypeToString(actionType),
        if (replyText != null && replyText.isNotEmpty) 'replyText': replyText,
      });
    }
  }

  NotificationActionType? _mapActionIdToType(String actionId) {
    return switch (actionId) {
      NotificationActionIds.accept => NotificationActionType.accept,
      NotificationActionIds.decline => NotificationActionType.decline,
      NotificationActionIds.reply => NotificationActionType.reply,
      NotificationActionIds.markRead => NotificationActionType.markRead,
      _ => null,
    };
  }

  String? _actionTypeToString(NotificationActionType type) {
    return switch (type) {
      NotificationActionType.accept => 'accept',
      NotificationActionType.decline => 'decline',
      NotificationActionType.reply => 'reply',
      NotificationActionType.markRead => 'mark_read',
    };
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
