import 'package:yalla_5roga/core/network/api_payload.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:yalla_5roga/core/constants/api_constants.dart';
import 'package:yalla_5roga/core/network/dio_interceptors.dart';
import 'package:yalla_5roga/core/network/api_client.dart';
import 'package:yalla_5roga/features/notifications/domain/entities/push_notification_payload.dart';

/// Handles interactive notification actions (accept, decline, reply, mark_read).
/// Makes authenticated API calls to the backend and returns success/failure.
class InteractiveNotificationHandler {
  InteractiveNotificationHandler(this._client);

  final ApiClient _client;

  /// Processes an interactive notification action.
  /// Returns true if the action was successful, false otherwise.
  Future<bool> handleAction(
    PushNotificationPayload payload,
    NotificationActionType actionType, {
    required String? currentUserId,
    required String? currentUserName,
  }) async {
    if (currentUserId == null) {
      debugPrint('[InteractiveNotification] No authenticated user');
      return false;
    }

    return switch (actionType) {
      NotificationActionType.accept => _respondInvitation(
        payload,
        accept: true,
      ),
      NotificationActionType.decline => _respondInvitation(
        payload,
        accept: false,
      ),
      NotificationActionType.reply => _replyToChat(
        payload,
        currentUserId: currentUserId,
        currentUserName: currentUserName,
      ),
      NotificationActionType.markRead => _markChatRead(payload.outingId),
    };
  }

  Future<bool> _respondInvitation(
    PushNotificationPayload payload, {
    required bool accept,
  }) async {
    final outing = payload.outingId;
    final invitation = payload.invitationId;
    final isOuting =
        payload.type == 'outing_invite' ||
        (outing != null && payload.type == 'invitation');
    if (isOuting ? outing == null : invitation == null) return false;
    final path = isOuting
        ? (accept
              ? ApiConstants.outingInvitationAccept(outing!)
              : ApiConstants.outingInvitationDecline(outing!))
        : (accept
              ? ApiConstants.invitationAccept(invitation!)
              : ApiConstants.invitationDecline(invitation!));
    try {
      final response = await _client.post<Map<String, dynamic>>(path);
      return apiPayload(response.data)['status'] ==
          (accept ? 'accepted' : 'declined');
    } on DioException {
      return false;
    }
  }

  Future<bool> _replyToChat(
    PushNotificationPayload payload, {
    required String currentUserId,
    required String? currentUserName,
  }) async {
    final outingId = payload.outingId;
    final replyText = payload.replyText;

    if (outingId == null) {
      debugPrint('[InteractiveNotification] Missing outingId for reply');
      return false;
    }
    if (replyText == null || replyText.trim().isEmpty) {
      debugPrint('[InteractiveNotification] Missing reply text');
      return false;
    }

    try {
      // Use timestamp-based client message ID for retry deduplication.
      final clientMessageId = 'notif-${DateTime.now().millisecondsSinceEpoch}';
      await _client.post<Map<String, dynamic>>(
        ApiConstants.outingChatMessages(outingId),
        data: {'text': replyText.trim(), 'clientMessageId': clientMessageId},
        options: Options(extra: {expectedUserIdKey: currentUserId}),
      );
      debugPrint('[InteractiveNotification] Reply sent to outing: $outingId');
      return true;
    } on DioException catch (error) {
      debugPrint('[InteractiveNotification] Reply failed: $error');
      return _isSuccessStatus(error);
    }
  }

  Future<bool> _markChatRead(String? outingId) async {
    if (outingId == null) {
      debugPrint('[InteractiveNotification] Missing outingId for markRead');
      return false;
    }
    try {
      await _client.patch<Map<String, dynamic>>(
        ApiConstants.outingChatRead(outingId),
      );
      debugPrint('[InteractiveNotification] Chat marked read: $outingId');
      return true;
    } on DioException catch (error) {
      debugPrint('[InteractiveNotification] Mark read failed: $error');
      return _isSuccessStatus(error);
    }
  }

  /// Determines if a failed request should be considered a success
  /// (e.g., for idempotent operations that already completed).
  bool _isSuccessStatus(DioException error) {
    // Idempotent operations may return 200 even after the action was already done,
    // or 404 if the resource was already removed/dealt with.
    // For accept/decline on an already-accepted/declined invitation, the API returns 200.
    final status = error.response?.statusCode;
    return status == 200 || status == 404;
  }
}
