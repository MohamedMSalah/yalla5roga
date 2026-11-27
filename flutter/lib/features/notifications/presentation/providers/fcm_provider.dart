import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/core/widgets/app_snackbar.dart';
import 'package:yalla_5roga/features/auth/presentation/providers/auth_provider.dart';
import 'package:yalla_5roga/features/notifications/data/services/interactive_notification_handler.dart';
import 'package:yalla_5roga/features/notifications/domain/entities/notification_item.dart';
import 'package:yalla_5roga/features/notifications/presentation/providers/notifications_provider.dart';
import 'package:yalla_5roga/features/notifications/domain/entities/push_authorization_status.dart';
import 'package:yalla_5roga/features/notifications/domain/entities/push_notification_payload.dart';
import 'package:yalla_5roga/features/notifications/domain/repositories/push_messaging_repository.dart';
import 'package:yalla_5roga/features/notifications/presentation/navigation/push_notification_navigator.dart';

/// App-wide FCM state: device token + deferred navigation from taps.
class FcmProvider extends ChangeNotifier {
  FcmProvider({
    required this.messaging,
    InteractiveNotificationHandler? interactiveHandler,
    this.actionDispatcher,
  }) : _interactiveHandler = interactiveHandler;

  final PushMessagingRepository messaging;
  final InteractiveNotificationHandler? _interactiveHandler;
  final Future<bool> Function(PushNotificationPayload)? actionDispatcher;

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
  String? _accountId;

  void bindAccount(String? uid) {
    if (_accountId == uid) return;
    _accountId = uid;
    _handledPushes.clear();
    if (_pendingTap?.recipientUserId != null &&
        _pendingTap?.recipientUserId != uid)
      _pendingTap = null;
  }

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
      'sessionId': item.meetupSessionId,
      'expiresAt': item.expiresAt,
      'notificationId': item.id,
    }),
    fromInbox: true,
    markRead: item.unread,
  );

  void _queueOrOpen(PushNotificationPayload payload) {
    final id = payload.deduplicationId;
    // For interactive actions, we allow reprocessing even if "handled"
    // because the action may have failed (e.g., network error).
    // The action handler will be called and we track success/failure separately.
    if (id != null &&
        !payload.isInteractiveAction &&
        _handledPushes.contains(id)) {
      return;
    }
    _pendingTap = payload;
    unawaited(_flushPendingNavigation());
  }

  Future<void> _flushPendingNavigation() async {
    final shell = _shell;
    if (_opening ||
        shell == null ||
        !shell.mounted ||
        !shell.read<AuthProvider>().isAuthenticated) {
      return;
    }

    // Capture and clear _pendingTap immediately to prevent stale references.
    final pending = _pendingTap;
    _pendingTap = null;

    if (pending == null) return;
    if (pending.recipientUserId != null &&
        pending.recipientUserId != shell.read<AuthProvider>().user?.id) {
      return;
    }

    final id = pending.deduplicationId;

    // Handle interactive action first if present.
    if (pending.isInteractiveAction && pending.actionType != null) {
      _opening = true;
      try {
        await _handleInteractiveAction(shell, pending, id);
      } finally {
        _opening = false;
        unawaited(_flushPendingNavigation());
      }
      return;
    }

    // For non-interactive notifications, mark as handled immediately.
    if (id != null && !pending.isInteractiveAction) {
      if (!_handledPushes.add(id)) return; // Already handled
      if (_handledPushes.length > 100) {
        _handledPushes.remove(_handledPushes.first);
      }
    }

    await _open(pending, fromInbox: false, markRead: true);
  }

  Future<void> _handleInteractiveAction(
    BuildContext shell,
    PushNotificationPayload payload,
    String? id,
  ) async {
    final auth = shell.read<AuthProvider>();
    final userId = auth.user?.id;
    final userName = auth.user?.name;

    if (userId == null) {
      debugPrint('[FCM] Interactive action but no authenticated user');
      return;
    }

    // For interactive actions, don't pre-mark as handled.
    // We'll mark as handled only after success.
    final alreadyHandled = id != null && _handledPushes.contains(id);

    // Execute the action.
    final success = actionDispatcher != null
        ? await actionDispatcher!(payload)
        : await _interactiveHandler?.handleAction(
            payload,
            payload.actionType!,
            currentUserId: userId,
            currentUserName: userName,
          );

    if (success == true) {
      if (!shell.mounted || shell.read<AuthProvider>().user?.id != userId) {
        return;
      }
      final notificationId = payload.notificationId;
      if (notificationId != null) {
        await shell.read<NotificationsProvider>().markRead(notificationId);
      }
      if (!shell.mounted || shell.read<AuthProvider>().user?.id != userId) {
        return;
      }
      // Action succeeded - mark as handled and show feedback.
      if (id != null) {
        _handledPushes.add(id);
        if (_handledPushes.length > 100) {
          _handledPushes.remove(_handledPushes.first);
        }
      }
      // Show success feedback based on action type.
      _showActionFeedback(shell, payload.actionType!);
    } else if (!alreadyHandled) {
      // Action failed but not yet handled - allow retry via notification tap.
      // Show error feedback.
      if (shell.mounted) {
        AppSnackBar.showError(shell.l10n.unexpectedError);
      }
    }
    // If already handled (retry after failure), we already showed feedback - do nothing more.
  }

  void _showActionFeedback(
    BuildContext shell,
    NotificationActionType actionType,
  ) {
    // For interactive actions, feedback is shown in the target screen.
    // Mark Read has no user-visible feedback needed.
    // For now, we rely on the navigation target to show appropriate feedback.
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
      await auth.synchronizeRestoredAccount();
      if (!shell.mounted || !isCurrent()) return;
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
