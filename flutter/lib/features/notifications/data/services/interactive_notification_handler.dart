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
    if (currentUserId == null || payload.recipientUserId != currentUserId) {
      debugPrint('[InteractiveNotification] No authenticated user');
      return false;
    }

    return switch (actionType) {
      NotificationActionType.accept => _respondInvitation(
        payload,
        accept: true,
        currentUserId: currentUserId,
      ),
      NotificationActionType.decline => _respondInvitation(
        payload,
        accept: false,
        currentUserId: currentUserId,
      ),
      NotificationActionType.reply => _replyToChat(
        payload,
        currentUserId: currentUserId,
        currentUserName: currentUserName,
      ),
      NotificationActionType.markRead => _markChatRead(payload, currentUserId),
    };
  }

  Future<bool> _respondInvitation(
    PushNotificationPayload payload, {
    required bool accept,
    required String currentUserId,
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
      final response = await _client.post<Map<String, dynamic>>(
        path,
        options: Options(extra: {expectedUserIdKey: currentUserId}),
      );
      final succeeded =
          apiPayload(response.data)['status'] ==
          (accept ? 'accepted' : 'declined');
      if (!succeeded) payload.data['retryableFailure'] = 'false';
      return succeeded;
    } on DioException catch (error) {
      return _failed(payload, error);
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
      // The persisted action UUID keeps native retries idempotent.
      final clientMessageId = payload.clientMessageId;
      if (clientMessageId == null ||
          !RegExp(
            r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
          ).hasMatch(clientMessageId)) {
        return false;
      }
      final response = await _client.post<Map<String, dynamic>>(
        ApiConstants.outingChatMessages(outingId),
        data: {'text': replyText.trim(), 'clientMessageId': clientMessageId},
        options: Options(extra: {expectedUserIdKey: currentUserId}),
      );
      final message = apiPayload(response.data);
      return message['id'] is String &&
          message['outing_id'] == outingId &&
          message['sender_id'] == currentUserId &&
          message['client_message_id'] == clientMessageId;
    } on DioException catch (error) {
      debugPrint('[InteractiveNotification] Reply failed: $error');
      return _failed(payload, error);
    }
  }

  Future<bool> _markChatRead(
    PushNotificationPayload payload,
    String currentUserId,
  ) async {
    final outingId = payload.outingId;
    if (outingId == null) {
      debugPrint('[InteractiveNotification] Missing outingId for markRead');
      return false;
    }
    try {
      final response = await _client.patch<Map<String, dynamic>>(
        ApiConstants.outingChatRead(outingId),
        options: Options(extra: {expectedUserIdKey: currentUserId}),
      );
      final read = apiPayload(response.data), readAt = read['last_read_at'];
      if (readAt is! String ||
          DateTime.tryParse(readAt) == null ||
          read['outing_id'] != outingId ||
          read['user_id'] != currentUserId)
        return false;
      payload.data['readAt'] = readAt;
      return true;
    } on DioException catch (error) {
      debugPrint('[InteractiveNotification] Mark read failed: $error');
      return _failed(payload, error);
    }
  }

  bool _failed(PushNotificationPayload payload, DioException error) {
    final status = error.response?.statusCode;
    if (status != null &&
        status >= 400 &&
        status < 500 &&
        ![401, 408, 429].contains(status)) {
      payload.data['retryableFailure'] = 'false';
    }
    return false;
  }
}
