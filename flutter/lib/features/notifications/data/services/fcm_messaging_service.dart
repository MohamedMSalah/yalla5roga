import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yalla_5roga/core/constants/app_constants.dart';
import 'package:yalla_5roga/features/notifications/data/services/local_notifications_service.dart';
import 'package:yalla_5roga/features/notifications/domain/entities/push_notification_payload.dart';

typedef PushMessageCallback = void Function(PushNotificationPayload payload);

/// Firebase Cloud Messaging client for this app (receive-only; no backend sync).
class FcmMessagingService {
  FcmMessagingService({
    required this._prefs,
    required this._localNotifications,
    FirebaseMessaging? messaging,
  }) : _messaging = messaging ?? FirebaseMessaging.instance;

  final SharedPreferences _prefs;
  final LocalNotificationsService _localNotifications;
  final FirebaseMessaging _messaging;

  final _tokenController = StreamController<String?>.broadcast();
  final List<StreamSubscription<dynamic>> _subscriptions = [];

  var _initialized = false;
  String? _token;
  PushMessageCallback? onOpenedFromNotification;

  String? get token => _token;
  Stream<String?> get tokenStream => _tokenController.stream;
  bool get isInitialized => _initialized;

  Future<void> initialize({required PushMessageCallback onOpened}) async {
    if (_initialized) return;
    onOpenedFromNotification = onOpened;

    try {
      await _localNotifications.initialize(onTap: onOpened);

      await _messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      _subscriptions.add(
        FirebaseMessaging.onMessage.listen(_onForegroundMessage),
      );
      _subscriptions.add(
        FirebaseMessaging.onMessageOpenedApp.listen(_onMessageOpenedApp),
      );
      _subscriptions.add(_messaging.onTokenRefresh.listen(_onTokenRefresh));

      _token = _prefs.getString(AppConstants.fcmTokenKey);
      if (_token != null) {
        _tokenController.add(_token);
      }

      _initialized = true;
    } catch (error, stack) {
      debugPrint('[FCM] initialize failed: $error\n$stack');
    }
  }

  /// Requests notification permission (where applicable) and refreshes the token.
  Future<AuthorizationStatus> requestPermission() async {
    try {
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );
      if (settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional) {
        await refreshToken();
      }
      return settings.authorizationStatus;
    } catch (error, stack) {
      debugPrint('[FCM] requestPermission failed: $error\n$stack');
      return AuthorizationStatus.notDetermined;
    }
  }

  Future<String?> refreshToken() async {
    try {
      final next = await _messaging.getToken();
      await _storeToken(next);
      return next;
    } catch (error, stack) {
      debugPrint('[FCM] getToken failed: $error\n$stack');
      return null;
    }
  }

  /// Cold-start: user launched the app by tapping a notification.
  Future<PushNotificationPayload?> takeInitialMessage() async {
    try {
      final message = await _messaging.getInitialMessage();
      if (message == null) return null;
      return PushNotificationPayload.fromRemoteMessage(message);
    } catch (error, stack) {
      debugPrint('[FCM] getInitialMessage failed: $error\n$stack');
      return null;
    }
  }

  Future<void> _onForegroundMessage(RemoteMessage message) async {
    if (kDebugMode) {
      debugPrint(
        '[FCM][foreground] id=${message.messageId} data=${message.data}',
      );
    }
    final payload = PushNotificationPayload.fromRemoteMessage(message);
    await _localNotifications.showFromPayload(payload);
  }

  void _onMessageOpenedApp(RemoteMessage message) {
    if (kDebugMode) {
      debugPrint('[FCM][opened] id=${message.messageId} data=${message.data}');
    }
    final payload = PushNotificationPayload.fromRemoteMessage(message);
    onOpenedFromNotification?.call(payload);
  }

  Future<void> _onTokenRefresh(String token) async {
    await _storeToken(token);
  }

  Future<void> _storeToken(String? token) async {
    _token = token;
    if (token == null || token.isEmpty) {
      await _prefs.remove(AppConstants.fcmTokenKey);
    } else {
      await _prefs.setString(AppConstants.fcmTokenKey, token);
    }
    if (!_tokenController.isClosed) {
      _tokenController.add(token);
    }
    if (token != null && token.isNotEmpty) {
      debugPrint('Firebase token is : "$token"');
    }
  }

  Future<void> dispose() async {
    for (final sub in _subscriptions) {
      await sub.cancel();
    }
    _subscriptions.clear();
    await _tokenController.close();
  }
}
