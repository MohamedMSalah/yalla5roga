import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:yalla_5roga/features/groups/presentation/pages/group_details_page.dart';
import 'package:yalla_5roga/features/notifications/domain/entities/push_notification_payload.dart';
import 'package:yalla_5roga/features/notifications/presentation/pages/notifications_page.dart';
import 'package:yalla_5roga/features/outings/presentation/pages/event_page.dart';
import 'package:yalla_5roga/features/outings/presentation/pages/outing_chat_page.dart';
import 'package:yalla_5roga/features/outings/presentation/providers/outings_provider.dart';

/// Maps a push payload to an in-app destination.
class PushNotificationNavigator {
  const PushNotificationNavigator._();

  static void open(PushNotificationPayload payload) {
    try {
      switch (payload.type) {
        case PushNotificationType.outing:
        case PushNotificationType.vote:
          _openOuting(payload.outingId);
          return;
        case PushNotificationType.group:
        case PushNotificationType.invitation:
          _openGroup(payload.groupId);
          return;
        case PushNotificationType.chat:
          _openChat(payload);
          return;
        case PushNotificationType.system:
        case PushNotificationType.unknown:
          _openNotificationsInbox();
          return;
      }
    } catch (error, stack) {
      debugPrint('[PushNav] open failed: $error\n$stack');
      _openNotificationsInbox();
    }
  }

  static void _openOuting(String? outingId) {
    if (outingId == null || outingId.isEmpty) {
      _openNotificationsInbox();
      return;
    }
    final context = Get.context;
    if (context == null) {
      _openNotificationsInbox();
      return;
    }
    final outing = context.read<OutingsProvider>().byId(outingId);
    Get.to(() => EventPage(event: outing));
  }

  static void _openGroup(String? groupId) {
    if (groupId == null || groupId.isEmpty) {
      _openNotificationsInbox();
      return;
    }
    Get.to(() => GroupDetailsPage(groupId: groupId));
  }

  static void _openChat(PushNotificationPayload payload) {
    final outingId = payload.chatId ?? payload.outingId;
    if (outingId == null || outingId.isEmpty) {
      _openNotificationsInbox();
      return;
    }
    final context = Get.context;
    if (context == null) {
      _openNotificationsInbox();
      return;
    }
    final outing = context.read<OutingsProvider>().byId(outingId);
    Get.to(() => OutingChatPage(event: outing));
  }

  static void _openNotificationsInbox() {
    Get.to(() => const NotificationsPage());
  }
}
