import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/core/widgets/app_snackbar.dart';
import 'package:yalla_5roga/features/auth/presentation/providers/auth_provider.dart';
import 'package:yalla_5roga/features/notifications/domain/entities/notification_item.dart';
import 'package:yalla_5roga/features/notifications/presentation/providers/notifications_provider.dart';
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
  BuildContext? _shell;
  final _handledPushes = <String>{};
  var _opening = false;
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
    if (initial != null) _queueOrOpen(initial);
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

  void attachShell(BuildContext context) {
    _shell = context;
    unawaited(_flushPendingNavigation());
  }

  void detachShell(BuildContext context) {
    if (identical(_shell, context)) _shell = null;
  }

  Future<void> openInboxItem(NotificationItem item) => _open(
    PushNotificationPayload.fromData({
      'type': item.eventType ?? item.type,
      'groupId': item.groupId,
      'outingId': item.outingId,
      'messageId': item.messageId,
      'notificationId': item.id,
    }),
    fromInbox: true,
    markRead: item.unread,
  );

  void _queueOrOpen(PushNotificationPayload payload) {
    final id = payload.deduplicationId;
    if (id != null && _handledPushes.contains(id)) return;
    _pendingTap = payload;
    unawaited(_flushPendingNavigation());
  }

  Future<void> _flushPendingNavigation() async {
    final shell = _shell;
    final pending = _pendingTap;
    if (_opening ||
        pending == null ||
        shell == null ||
        !shell.mounted ||
        !shell.read<AuthProvider>().isAuthenticated) {
      return;
    }
    _pendingTap = null;
    final id = pending.deduplicationId;
    if (id != null && !_handledPushes.add(id)) return;
    if (_handledPushes.length > 100) {
      _handledPushes.remove(_handledPushes.first);
    }
    await _open(pending, fromInbox: false, markRead: true);
  }

  Future<void> _open(
    PushNotificationPayload payload, {
    required bool fromInbox,
    required bool markRead,
  }) async {
    final shell = _shell;
    if (_opening || shell == null || !shell.mounted) return;
    final auth = shell.read<AuthProvider>();
    final userId = auth.user?.id;
    if (!auth.isAuthenticated || userId == null) return;
    if (payload.recipientUserId != null && payload.recipientUserId != userId) {
      AppSnackBar.showError(shell.l10n.errorForbidden);
      return;
    }

    _opening = true;
    bool isCurrent() =>
        identical(_shell, shell) &&
        auth.isAuthenticated &&
        auth.user?.id == userId;
    try {
      final notificationId = payload.notificationId;
      if (markRead && notificationId != null) {
        unawaited(shell.read<NotificationsProvider>().markRead(notificationId));
      }
      await PushNotificationNavigator.open(
        shell,
        payload,
        isCurrent: isCurrent,
        fromInbox: fromInbox,
      );
    } catch (error, stack) {
      debugPrint('[PushNav] open failed: $error\n$stack');
      if (shell.mounted && isCurrent()) {
        AppSnackBar.showError(shell.l10n.unexpectedError);
      }
    } finally {
      _opening = false;
      unawaited(_flushPendingNavigation());
    }
  }

  @override
  void dispose() {
    _tokenSub?.cancel();
    super.dispose();
  }
}
