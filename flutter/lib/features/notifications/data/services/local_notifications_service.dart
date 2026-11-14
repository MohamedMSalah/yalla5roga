import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' show Locale;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:yalla_5roga/core/localization/l10n.dart';
import 'package:yalla_5roga/core/constants/app_constants.dart';
import 'package:yalla_5roga/core/network/api_client.dart';
import 'package:yalla_5roga/core/network/api_payload.dart';
import 'package:yalla_5roga/core/network/dio_interceptors.dart';
import 'package:yalla_5roga/features/notifications/domain/entities/notification_item.dart';
import 'package:yalla_5roga/features/notifications/domain/entities/push_notification_payload.dart';

import 'notification_background_runtime.dart';

typedef LocalNotificationTapCallback = void Function(
  PushNotificationPayload payload,
);

abstract class NotificationActionIds {
  static const accept = 'accept_action', decline = 'decline_action';
  static const reply = 'reply_action',
      markRead = 'mark_read_action',
      retry = 'retry_action';
}

/// One renderer for FCM in foreground, background and a terminated Android process.
class LocalNotificationsService {
  LocalNotificationsService({
    this.client,
    this.currentUserId,
    this.isViewingChat,
  });
  final ApiClient? client;
  final String? Function()? currentUserId;
  final bool Function(String)? isViewingChat;
  final _plugin = FlutterLocalNotificationsPlugin();
  final _store = SharedPreferencesAsync();
  var _initialized = false;
  SharedPreferences? _preferences;
  L10n get _l10n =>
      L10n(Locale(_preferences?.getString(AppConstants.localeKey) ?? 'ar'));
  static const chatCategory = 'outing_chat';
  static const _nativeActions = MethodChannel(
    'yalla5roga/chat_notification_actions',
  );
  static const _channels = <String, String>{
    'chat': 'Chat messages',
    'mentions': 'Direct mentions',
    'invitations': 'Invitations',
    'groups': 'Group activity',
    'outings': 'Outings',
    'voting': 'Voting',
    'reminders': 'Reminders',
  };
  String _channelLabel(String key) {
    if ((_preferences?.getString(AppConstants.localeKey) ?? 'ar') != 'ar')
      return _channels[key]!;
    return const {
      'chat': 'رسائل المحادثة',
      'mentions': 'الإشارات إليك',
      'invitations': 'الدعوات',
      'groups': 'نشاط المجموعات',
      'outings': 'الخروجات',
      'voting': 'التصويت',
      'reminders': 'التذكيرات',
    }[key]!;
  }

  LocalNotificationTapCallback? onNotificationTap;
  Future<void> Function(PushNotificationPayload)? onAction;
  bool get isInitialized => _initialized;
  static String _prefix(String uid) =>
      'system_display.${base64Url.encode(utf8.encode(uid))}.';
  static int systemId(PushNotificationPayload p) =>
      int.parse(
        sha256
            .convert(
              utf8.encode(
                '${p.recipientUserId}|${p.notificationId ?? p.deduplicationId}',
              ),
            )
            .toString()
            .substring(0, 8),
        radix: 16,
      ) &
      0x7fffffff;

  Future<void> initialize({LocalNotificationTapCallback? onTap}) async {
    if (onTap != null) onNotificationTap = onTap;
    if (_initialized) return;
    _preferences = await SharedPreferences.getInstance();
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      _nativeActions.setMethodCallHandler((call) async {
        if (call.method == 'chatAction' && call.arguments is Map) {
          final payload = PushNotificationPayload.fromData(
            Map<String, dynamic>.from(call.arguments as Map),
          );
          await _respond(payload);
        }
      });
    }
    final darwin = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
      notificationCategories: [
        DarwinNotificationCategory(
          chatCategory,
          actions: [
            DarwinNotificationAction.text(
              NotificationActionIds.reply,
              _l10n.reply,
              buttonTitle: _l10n.sendMessage,
              placeholder: _l10n.writeMessage,
              options: {
                DarwinNotificationActionOption.foreground,
                DarwinNotificationActionOption.authenticationRequired,
              },
            ),
            DarwinNotificationAction.plain(
              NotificationActionIds.markRead,
              _l10n.markAsRead,
              options: {
                DarwinNotificationActionOption.foreground,
                DarwinNotificationActionOption.authenticationRequired,
              },
            ),
          ],
        ),
      ],
    );
    final ok = await _plugin.initialize(
      settings: InitializationSettings(
        android: const AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: darwin,
      ),
      onDidReceiveNotificationResponse: (response) {
        final p = decodeResponse(response);
        if (p != null) unawaited(_respond(p));
      },
      onDidReceiveBackgroundNotificationResponse:
          notificationActionBackgroundHandler,
    );
    if (ok == false) return;
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    for (final entry in _channels.entries) {
      await android?.createNotificationChannel(
        AndroidNotificationChannel(
          'yalla_${entry.key}_v1',
          _channelLabel(entry.key),
          importance: entry.key == 'mentions'
              ? Importance.high
              : Importance.defaultImportance,
          showBadge: true,
        ),
      );
    }
    _initialized = true;
  }

  Future<void> _respond(PushNotificationPayload payload) async {
    if (payload.isInteractiveAction && onAction != null) {
      await onAction!(payload);
    } else {
      onNotificationTap?.call(payload);
    }
  }

  List<AndroidNotificationAction> _actions(PushNotificationPayload p) {
    if (p.data['actionRetry'] == 'true')
      return [
        AndroidNotificationAction(
          NotificationActionIds.retry,
          _l10n.retry,
          cancelNotification: false,
        ),
      ];
    if (p.type == 'group_invite' && p.invitationId != null)
      return [
        AndroidNotificationAction(
          NotificationActionIds.accept,
          _l10n.accept,
          cancelNotification: false,
        ),
        AndroidNotificationAction(
          NotificationActionIds.decline,
          _l10n.decline,
          cancelNotification: false,
        ),
      ];
    if (p.destination == NotificationDestination.chat && p.outingId != null)
      return [
        if (p.data['chatOpen'] != 'false')
          AndroidNotificationAction(
            NotificationActionIds.reply,
            _l10n.reply,
            cancelNotification: false,
            semanticAction: SemanticAction.reply,
            inputs: [AndroidNotificationActionInput(label: _l10n.writeMessage)],
          ),
        AndroidNotificationAction(
          NotificationActionIds.markRead,
          _l10n.markAsRead,
          cancelNotification: false,
          semanticAction: SemanticAction.markAsRead,
        ),
      ];
    return [];
  }

  Future<void> showFromPayload(PushNotificationPayload incoming) async {
    if (!_initialized) return;
    final uid = currentUserId?.call();
    if (uid == null || incoming.recipientUserId != uid) return;
    final count = int.tryParse(incoming.data['unreadCount'] ?? '');
    if (count != null) await _store.setInt('${_prefix(uid)}unread', count);
    final control = incoming.type;
    if (control == 'conversation_read') {
      if (incoming.notificationId != null) {
        await _cancelWhere(
          uid,
          (p) => p.notificationId == incoming.notificationId,
        );
        return;
      }
      if (incoming.data['readAll'] == 'true') {
        final cutoff = incoming.createdAt ?? DateTime.now();
        await _cancelWhere(uid, (p) => p.createdAt?.isAfter(cutoff) != true);
        return;
      }
      if (incoming.outingId == null) return;
      await _cancelWhere(
        uid,
        (p) =>
            p.outingId == incoming.outingId &&
            p.destination == NotificationDestination.chat &&
            (p.createdAt?.isAfter(
                  DateTime.tryParse(incoming.data['readAt'] ?? '') ??
                      DateTime.now(),
                ) !=
                true),
      );
      return;
    }
    if (control == 'invitation_resolved') {
      if (incoming.invitationId != null)
        await _cancelWhere(uid, (p) => p.invitationId == incoming.invitationId);
      else if (incoming.outingId != null)
        await _cancelWhere(
          uid,
          (p) =>
              p.outingId == incoming.outingId &&
              p.destination == NotificationDestination.invitation,
        );
      return;
    }
    if (control == 'chat_deleted') {
      await _cancelWhere(uid, (p) => p.messageId == incoming.messageId);
      return;
    }
    final update = control == 'chat_updated';
    var payload = incoming;
    final notificationId = incoming.notificationId;
    if (notificationId == null) return;
    final savedKey = '${_prefix(uid)}$notificationId';
    if (update && await _store.getString(savedKey) == null) return;
    if (update &&
        !(await _plugin.getActiveNotifications()).any(
          (n) => n.id == systemId(incoming),
        )) {
      await _cancel(incoming);
      return;
    }
    final event = incoming.deduplicationId;
    final seenKey = '${_prefix(uid)}seen.$event';
    if (!update && event != null && await _store.getBool(seenKey) == true)
      return;
    // A queued payload can be stale after an edit, deletion or membership removal.
    // Prefer authoritative content. Offline display contains no private message text.
    try {
      final response = await client?.get<Map<String, dynamic>>(
        '/api/notifications/$notificationId/system-payload',
        options: Options(extra: {expectedUserIdKey: uid}),
      );
      if (currentUserId?.call() != uid) return;
      final result = apiPayload(response?.data);
      if (result['available'] != true || result['payload'] is! Map) {
        await _cancel(payload);
        return;
      }
      payload = PushNotificationPayload.fromData({
        ...Map<String, dynamic>.from(result['payload'] as Map),
        'eventId': incoming.eventId ?? incoming.pushId ?? '',
        'type': update ? 'chat_message' : incoming.type,
        'notificationType': update ? 'chat_message' : incoming.type,
      });
    } on DioException {
      if (update) {
        await _cancel(payload);
        return;
      }
      payload = PushNotificationPayload.fromData({
        ...incoming.toLocalPayloadMap(),
        'title': AppConstants.appName,
        'body': _l10n.notifications,
        'redacted': 'true',
        'lockScreenPreview': 'false',
      });
    }
    if (payload.outingId != null &&
        payload.destination == NotificationDestination.chat &&
        isViewingChat?.call(payload.outingId!) == true)
      return;
    if (currentUserId?.call() != uid) return;
    await _render(payload, silent: update);
    if (event != null) await _store.setBool(seenKey, true);
    // Bounded persisted deduplication; display records are pruned on resume.
    final seen = (await _store.getKeys())
        .where((k) => k.startsWith('${_prefix(uid)}seen.'))
        .toList();
    for (final key in seen.take((seen.length - 300).clamp(0, seen.length))) {
      await _store.remove(key);
    }
  }

  String _category(PushNotificationPayload p) => switch (p.destination) {
    NotificationDestination.chat => p.isMention ? 'mentions' : 'chat',
    NotificationDestination.invitation => 'invitations',
    NotificationDestination.group ||
    NotificationDestination.groupMembers => 'groups',
    NotificationDestination.placeVoting => 'voting',
    _ => p.type.contains('reminder') ? 'reminders' : 'outings',
  };

  Future<void> _render(PushNotificationPayload p, {bool silent = false}) async {
    final uid = p.recipientUserId;
    if (uid == null || currentUserId?.call() != uid) return;
    if (!kIsWeb &&
        defaultTargetPlatform == TargetPlatform.android &&
        await _plugin
                .resolvePlatformSpecificImplementation<
                  AndroidFlutterLocalNotificationsPlugin
                >()
                ?.areNotificationsEnabled() ==
            false)
      return;
    final category = _category(p),
        chat = p.destination == NotificationDestination.chat;
    final title = p.title ?? AppConstants.appName, body = p.body ?? '';
    final when =
        DateTime.tryParse(p.data['messageSentAt'] ?? '') ??
        p.createdAt ??
        DateTime.now();
    final redacted = p.data['redacted'] == 'true';
    final unread =
        int.tryParse(p.data['unreadCount'] ?? '') ??
        await _store.getInt('${_prefix(uid)}unread') ??
        1;
    await _plugin.show(
      id: systemId(p),
      title: title,
      body: body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          'yalla_${category}_v1',
          _channelLabel(category),
          icon: '@mipmap/ic_launcher',
          importance: p.isMention
              ? Importance.high
              : Importance.defaultImportance,
          priority: p.isMention ? Priority.high : Priority.defaultPriority,
          groupKey: chat ? 'chat.$uid.${p.outingId}' : null,
          groupAlertBehavior: GroupAlertBehavior.children,
          category: chat ? AndroidNotificationCategory.message : null,
          styleInformation: chat && !redacted
              ? MessagingStyleInformation(
                  Person(name: _l10n.you),
                  conversationTitle: p.data['conversationTitle'] ?? title,
                  groupConversation: true,
                  messages: [
                    Message(
                      body,
                      when,
                      Person(
                        name: p.data['senderName'] ?? title,
                        key: p.data['senderId'],
                      ),
                    ),
                  ],
                )
              : BigTextStyleInformation(body),
          when: when.millisecondsSinceEpoch,
          number: unread,
          onlyAlertOnce: true,
          silent: silent,
          visibility: p.lockScreenPreview
              ? NotificationVisibility.public
              : NotificationVisibility.secret,
          actions: redacted ? [] : _actions(p),
        ),
        iOS: DarwinNotificationDetails(
          categoryIdentifier: chat ? chatCategory : null,
          presentAlert: true,
          presentBadge: true,
          presentSound: !silent,
        ),
      ),
      payload: jsonEncode(p.toLocalPayloadMap()),
    );
    await _store.setString(
      '${_prefix(uid)}${p.notificationId}',
      jsonEncode(p.toLocalPayloadMap()),
    );
    if (chat) await _updateChatSummary(p);
    // Recheck after asynchronous native display so an account switch cannot leak it.
    if (currentUserId?.call() != uid) await _cancel(p);
  }

  Future<void> _cancel(PushNotificationPayload p) async {
    await _plugin.cancel(id: systemId(p));
    if (p.recipientUserId != null && p.notificationId != null)
      await _store.remove('${_prefix(p.recipientUserId!)}${p.notificationId}');
    if (p.destination == NotificationDestination.chat)
      await _updateChatSummary(p);
  }

  Future<void> _updateChatSummary(PushNotificationPayload p) async {
    if (kIsWeb ||
        defaultTargetPlatform != TargetPlatform.android ||
        p.recipientUserId == null ||
        p.outingId == null)
      return;
    final uid = p.recipientUserId!, outing = p.outingId!;
    final summaryId = systemId(
      PushNotificationPayload.fromData({
        'recipientUserId': uid,
        'notificationId': 'summary:$outing',
      }),
    );
    final tag = 'summary.$uid';
    final active = (await _plugin.getActiveNotifications())
        .map((n) => n.id)
        .toSet();
    final children = <PushNotificationPayload>[];
    for (final key in await _store.getKeys()) {
      if (!key.startsWith(_prefix(uid)) ||
          key.contains('.seen.') ||
          key.endsWith('.unread'))
        continue;
      final raw = await _store.getString(key);
      if (raw == null) continue;
      final item = PushNotificationPayload.fromData(
        Map<String, dynamic>.from(jsonDecode(raw) as Map),
      );
      if (item.destination == NotificationDestination.chat &&
          item.outingId == outing &&
          active.contains(systemId(item)))
        children.add(item);
    }
    if (children.length < 2 || currentUserId?.call() != uid) {
      await _plugin.cancel(id: summaryId, tag: tag);
      return;
    }
    children.sort(
      (a, b) => (b.createdAt ?? DateTime(1970)).compareTo(
        a.createdAt ?? DateTime(1970),
      ),
    );
    final latest = children.first;
    await _plugin.show(
      id: summaryId,
      title: latest.data['conversationTitle'] ?? latest.title,
      body: _l10n.notifications,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          'yalla_chat_v1',
          _channelLabel('chat'),
          tag: tag,
          icon: '@mipmap/ic_launcher',
          groupKey: 'chat.$uid.$outing',
          setAsGroupSummary: true,
          groupAlertBehavior: GroupAlertBehavior.children,
          silent: true,
          onlyAlertOnce: true,
          number: children.length,
          visibility: children.every((c) => c.lockScreenPreview)
              ? NotificationVisibility.public
              : NotificationVisibility.secret,
          styleInformation: InboxStyleInformation(
            children
                .take(5)
                .map((c) => '${c.data['senderName'] ?? c.title}: ${c.body}')
                .toList(),
          ),
        ),
      ),
      payload: jsonEncode({
        ...latest.toLocalPayloadMap(),
        'actionType': 'open',
      }),
    );
    if (currentUserId?.call() != uid)
      await _plugin.cancel(id: summaryId, tag: tag);
  }

  Future<void> _cancelWhere(
    String uid,
    bool Function(PushNotificationPayload) predicate,
  ) async {
    for (final key in await _store.getKeys()) {
      if (!key.startsWith(_prefix(uid)) ||
          key.contains('.seen.') ||
          key.endsWith('.unread'))
        continue;
      final raw = await _store.getString(key);
      if (raw == null) continue;
      final p = PushNotificationPayload.fromData(
        Map<String, dynamic>.from(jsonDecode(raw) as Map),
      );
      if (predicate(p)) await _cancel(p);
    }
  }

  Future<void> completeAction(PushNotificationPayload p) async {
    if (p.recipientUserId != currentUserId?.call()) return;
    if (p.actionType == NotificationActionType.markRead) {
      final cutoff =
          DateTime.tryParse(
            p.data['readAt'] ?? p.data['actionStartedAt'] ?? '',
          ) ??
          p.createdAt ??
          DateTime.now();
      await _cancelWhere(
        p.recipientUserId!,
        (other) =>
            other.outingId == p.outingId &&
            other.destination == NotificationDestination.chat &&
            other.createdAt?.isAfter(cutoff) != true,
      );
    } else {
      await _cancel(p);
    }
  }

  Future<void> showActionFailure(PushNotificationPayload p) => _render(
    PushNotificationPayload.fromData({
      ...p.toLocalPayloadMap(),
      'actionRetry': '${p.data['retryableFailure'] != 'false'}',
      'title': _l10n.unexpectedError,
      'body': p.data['retryableFailure'] == 'false'
          ? _l10n.notificationTargetUnavailable
          : _l10n.retry,
      if (p.data['retryableFailure'] == 'false') 'redacted': 'true',
      'lockScreenPreview': 'false',
    }),
    silent: true,
  );

  /// Uses the existing complete inbox sync, without making per-row API requests.
  Future<void> reconcile(
    List<NotificationItem> items,
    int unreadCount,
    Map<String, bool> preferences,
  ) async {
    final uid = currentUserId?.call();
    if (!_initialized || uid == null) return;
    await _store.setInt('${_prefix(uid)}unread', unreadCount);
    final byId = {for (final item in items) item.id: item};
    final active = (await _plugin.getActiveNotifications())
        .map((n) => n.id)
        .toSet();
    await _cancelWhere(
      uid,
      (p) =>
          !active.contains(systemId(p)) ||
          byId[p.notificationId]?.unread != true ||
          preferences['pushEnabled'] == false ||
          p.destination == NotificationDestination.chat &&
              (p.data['directMention'] == 'true'
                  ? preferences['mentions'] == false
                  : preferences['chatMessages'] == false),
    );
    for (final key in await _store.getKeys()) {
      if (!key.startsWith(_prefix(uid)) ||
          key.contains('.seen.') ||
          key.endsWith('.unread') ||
          currentUserId?.call() != uid)
        continue;
      final raw = await _store.getString(key);
      if (raw == null) continue;
      final p = PushNotificationPayload.fromData(
        Map<String, dynamic>.from(jsonDecode(raw) as Map),
      );
      final item = byId[p.notificationId];
      if (item != null &&
          active.contains(systemId(p)) &&
          p.data['actionRetry'] != 'true') {
        await _render(
          PushNotificationPayload.fromData({
            ...p.toLocalPayloadMap(),
            'body': p.data['redacted'] == 'true'
                ? _l10n.notifications
                : item.body,
            'lockScreenPreview': '${preferences['lockScreenPreview'] == true}',
            'unreadCount': '$unreadCount',
          }),
          silent: true,
        );
      }
    }
  }

  Future<void> clearAccount(String uid) async {
    await _cancelWhere(uid, (_) => true);
    for (final key in await _store.getKeys()) {
      if (key.startsWith(_prefix(uid))) await _store.remove(key);
    }
    for (final n in await _plugin.getActiveNotifications()) {
      if (n.id != null && n.tag == 'summary.$uid')
        await _plugin.cancel(id: n.id!, tag: n.tag);
    }
  }

  Future<PushNotificationPayload?> takeInitialMessage() async {
    if (!_initialized) return null;
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      final data = await _nativeActions.invokeMapMethod<String, dynamic>(
        'takeInitialAction',
      );
      if (data != null) return PushNotificationPayload.fromData(data);
    }
    final details = await _plugin.getNotificationAppLaunchDetails();
    return details?.didNotificationLaunchApp == true &&
            details?.notificationResponse != null
        ? decodeResponse(details!.notificationResponse!)
        : null;
  }

  static PushNotificationPayload? decodeResponse(
    NotificationResponse response,
  ) {
    if (response.payload == null) return null;
    try {
      final data = Map<String, dynamic>.from(
        jsonDecode(response.payload!) as Map,
      );
      final action = switch (response.actionId) {
        NotificationActionIds.accept => 'accept',
        NotificationActionIds.decline => 'decline',
        NotificationActionIds.reply => 'reply',
        NotificationActionIds.markRead => 'mark_read',
        NotificationActionIds.retry => data['actionType'] as String?,
        _ => null,
      };
      return PushNotificationPayload.fromData({
        ...data,
        'actionType': action ?? 'open',
        if (action != null)
          'actionStartedAt': DateTime.now().toUtc().toIso8601String(),
        if (response.input?.trim().isNotEmpty == true)
          'replyText': response.input!.trim(),
      });
    } catch (_) {
      return null;
    }
  }
}
