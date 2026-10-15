import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:yalla_5roga/features/notifications/domain/entities/push_authorization_status.dart';
import 'package:yalla_5roga/features/notifications/domain/entities/push_notification_payload.dart';
import 'package:yalla_5roga/features/notifications/domain/repositories/push_messaging_repository.dart';
import 'package:yalla_5roga/features/notifications/presentation/navigation/push_notification_navigator.dart';

/// App-wide FCM state: device token + deferred navigation from taps.
class FcmProvider extends ChangeNotifier {
  FcmProvider({required this.messaging});

  final PushMessagingRepository messaging;

  StreamSubscription<String?>? _tokenSub;
  var _ready = false;
  var _initialTapHandled = false;
  String? _token;
  PushNotificationPayload? _pendingTap;
  PushAuthorizationStatus? _authorizationStatus;

  bool get isReady => _ready;
  String? get token => _token;
  PushAuthorizationStatus? get authorizationStatus => _authorizationStatus;
  PushNotificationPayload? get pendingTap => _pendingTap;

  Future<void> initialize() async {
    if (_ready) return;

    await messaging.initialize(onOpened: _queueOrOpen);
    _token = messaging.token;
    _tokenSub = messaging.tokenStream.listen((value) {
      if (_token == value) return;
      _token = value;
      notifyListeners();
    });

    _ready = true;
    notifyListeners();

    final initial = await messaging.takeInitialMessage();
    if (initial != null && !_initialTapHandled) {
      _initialTapHandled = true;
      _queueOrOpen(initial);
    }
  }

  Future<void> afterPermissionPrompt() async {
    try {
      _authorizationStatus = await messaging.requestPermission();
      _token = messaging.token;
      notifyListeners();
    } catch (error, stack) {
      debugPrint('[FCM] afterPermissionPrompt failed: $error\n$stack');
    }
  }

  Future<String?> refreshToken() async {
    final token = await messaging.refreshToken();
    _token = token;
    notifyListeners();
    return token;
  }

  void flushPendingNavigation() {
    final pending = _pendingTap;
    if (pending == null) return;
    _pendingTap = null;
    PushNotificationNavigator.open(pending);
  }

  void _queueOrOpen(PushNotificationPayload payload) {
    if (Get.key.currentState == null) {
      _pendingTap = payload;
      notifyListeners();
      return;
    }
    PushNotificationNavigator.open(payload);
  }

  @override
  void dispose() {
    _tokenSub?.cancel();
    super.dispose();
  }
}
