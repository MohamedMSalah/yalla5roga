import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yalla_5roga/features/notifications/data/services/interactive_notification_handler.dart';
import 'package:yalla_5roga/features/notifications/domain/entities/push_notification_payload.dart';

/// One account-bound dispatcher for native actions in either Flutter isolate.
/// Drafts survive process death; only backend acknowledgement completes an action.
class NotificationActionDispatcher {
  NotificationActionDispatcher({
    required this.handler,
    required this.currentUserId,
    required this.onSuccess,
    required this.onFailure,
  });
  final InteractiveNotificationHandler handler;
  final String? Function() currentUserId;
  final Future<void> Function(PushNotificationPayload) onSuccess, onFailure;
  final _prefs = SharedPreferencesAsync();
  final _inFlight = <String>{};

  static String prefix(String uid) =>
      'system_action.${base64Url.encode(utf8.encode(uid))}.';
  static Map<String, dynamic> _record(String? raw) {
    try {
      return raw == null
          ? {}
          : Map<String, dynamic>.from(jsonDecode(raw) as Map);
    } catch (_) {
      return {};
    }
  }

  static String _uuid(String value) {
    final h = sha256.convert(utf8.encode(value)).toString();
    return '${h.substring(0, 8)}-${h.substring(8, 12)}-5${h.substring(13, 16)}-a${h.substring(17, 20)}-${h.substring(20, 32)}';
  }

  Future<bool> dispatch(
    PushNotificationPayload incoming, {
    bool explicitRetry = true,
  }) async {
    final uid = currentUserId();
    if (uid == null ||
        incoming.recipientUserId != uid ||
        incoming.actionType == null)
      return false;
    final actionId = _uuid(
      '$uid|${incoming.notificationId ?? incoming.deduplicationId}|${incoming.actionType}|${incoming.replyText ?? ''}',
    );
    final key = '${prefix(uid)}$actionId';
    if (!_inFlight.add(key)) return false;
    try {
      final raw = await _prefs.getString(key);
      final stored = _record(raw);
      final payload = PushNotificationPayload.fromData({
        ...incoming.toLocalPayloadMap(),
        'clientMessageId': actionId,
      });
      if (stored['done'] == true) {
        await onSuccess(payload);
        return true;
      }
      var attempts = (stored['attempts'] as int?) ?? 0;
      final retryAt = (stored['retryAt'] as int?) ?? 0;
      if (!explicitRetry &&
          (stored['retryable'] == false ||
              attempts >= 5 ||
              DateTime.now().millisecondsSinceEpoch < retryAt))
        return false;
      if (explicitRetry && attempts >= 5) attempts = 0;
      // Keep separate keys per action to avoid cross-isolate read/modify/write loss.
      final record = <String, dynamic>{
        'payload': payload.toLocalPayloadMap(),
        'done': false,
        'createdAt':
            stored['createdAt'] ?? DateTime.now().millisecondsSinceEpoch,
        'attempts': attempts + 1,
        'retryAt':
            DateTime.now().millisecondsSinceEpoch +
            (10000 * (1 << attempts.clamp(0, 5))),
      };
      await _prefs.setString(key, jsonEncode(record));
      if (currentUserId() != uid) return false;
      final ok = await handler.handleAction(
        payload,
        payload.actionType!,
        currentUserId: uid,
        currentUserName: null,
      );
      if (currentUserId() != uid) return false;
      if (ok) {
        await _prefs.setString(
          key,
          jsonEncode({...record, 'done': true, 'payload': <String, String>{}}),
        );
        await onSuccess(payload);
      } else {
        await _prefs.setString(
          key,
          jsonEncode({
            ...record,
            'retryable': payload.data['retryableFailure'] != 'false',
          }),
        );
        await onFailure(payload);
      }
      return ok;
    } finally {
      _inFlight.remove(key);
      await _prune(uid);
    }
  }

  Future<void> retryPending() async {
    final uid = currentUserId();
    if (uid == null) return;
    await _prune(uid);
    for (final key in await _prefs.getKeys()) {
      if (!key.startsWith(prefix(uid)) || currentUserId() != uid) continue;
      final raw = await _prefs.getString(key);
      if (raw == null) continue;
      final record = _record(raw);
      if (record['done'] != true && record['payload'] is Map) {
        await dispatch(
          PushNotificationPayload.fromData(
            Map<String, dynamic>.from(record['payload'] as Map),
          ),
          explicitRetry: false,
        );
      }
    }
  }

  Future<void> clearAccount(String uid) async {
    for (final key in await _prefs.getKeys()) {
      if (key.startsWith(prefix(uid))) await _prefs.remove(key);
    }
  }

  Future<void> _prune(String uid) async {
    final records = <(String, int)>[];
    for (final key in await _prefs.getKeys()) {
      if (!key.startsWith(prefix(uid))) continue;
      final raw = await _prefs.getString(key);
      if (raw == null) continue;
      final stamp = _record(raw)['createdAt'] as int? ?? 0;
      records.add((key, stamp));
    }
    records.sort((a, b) => b.$2.compareTo(a.$2));
    for (var i = 0; i < records.length; i++) {
      if (i >= 100 ||
          records[i].$2 <
              DateTime.now()
                  .subtract(const Duration(days: 7))
                  .millisecondsSinceEpoch)
        await _prefs.remove(records[i].$1);
    }
  }
}
