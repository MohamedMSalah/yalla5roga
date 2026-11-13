import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:yalla_5roga/core/error/app_error_feedback.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/core/widgets/app_snackbar.dart';
import 'package:yalla_5roga/features/chat/presentation/pages/outing_chat_page.dart';
import 'package:yalla_5roga/features/groups/presentation/pages/group_details_page.dart';
import 'package:yalla_5roga/features/groups/presentation/pages/group_info_page.dart';
import 'package:yalla_5roga/features/groups/presentation/providers/groups_provider.dart';
import 'package:yalla_5roga/features/invitations/presentation/pages/invitations_page.dart';
import 'package:yalla_5roga/features/notifications/domain/entities/push_notification_payload.dart';
import 'package:yalla_5roga/features/notifications/presentation/pages/notifications_page.dart';
import 'package:yalla_5roga/features/outings/domain/entities/outing.dart';
import 'package:yalla_5roga/features/outings/presentation/pages/event_page.dart';
import 'package:yalla_5roga/features/outings/presentation/providers/outings_provider.dart';

class PushNotificationNavigator {
  const PushNotificationNavigator._();

  static Future<void> open(
    BuildContext context,
    PushNotificationPayload payload, {
    required bool Function() isCurrent,
    required bool fromInbox,
  }) async {
    // Handle group_invite notifications → InvitationsPage
    if (payload.type == 'group_invite' ||
        (payload.type == 'invitation' && payload.outingId == null)) {
      Get.to(
        () => const InvitationsPage(),
        routeName: '/notification/invitation',
      );
      return;
    }

    final destination = payload.destination;
    if (destination == NotificationDestination.inbox) {
      if (!fromInbox) Get.to(() => const NotificationsPage());
      return;
    }

    if (destination == NotificationDestination.group ||
        destination == NotificationDestination.groupMembers) {
      final id = payload.groupId;
      if (id == null) {
        AppSnackBar.showError(context.l10n.errorNotFound);
        return;
      }
      final groups = context.read<GroupsProvider>();
      final group = await groups.ensureGroupLoaded(
        id,
        forceRefresh: true,
        allowStale: false,
      );
      if (!context.mounted || !isCurrent()) return;
      if (group == null) {
        AppSnackBar.showError(context.l10n.notificationTargetUnavailable);
        return;
      }
      if (destination == NotificationDestination.groupMembers) {
        Get.to(
          () => GroupInfoPage(groupId: id, focusMembers: true),
          routeName: '/notification/group/$id/members',
        );
      } else {
        Get.to(
          () => GroupDetailsPage(groupId: id),
          routeName: '/notification/group/$id',
        );
      }
      return;
    }

    final id = payload.outingId;
    if (id == null) {
      AppSnackBar.showError(context.l10n.errorNotFound);
      return;
    }
    final outings = context.read<OutingsProvider>();
    final result = await outings.repository.refreshLifecycle(
      outingId: id,
      forceRefresh: true,
    );
    if (!context.mounted || !isCurrent()) return;
    result.fold(
      (failure) => AppErrorFeedback.report(failure, kind: AppErrorKind.load),
      (snapshot) {
        Outing? outing;
        for (final item in snapshot.outings) {
          if (item.id == id) {
            outing = item;
            break;
          }
        }
        if (outing == null) {
          AppSnackBar.showError(context.l10n.errorNotFound);
          return;
        }
        outings.applyDetailsSnapshot(snapshot);
        final event = outing;
        if (destination == NotificationDestination.chat) {
          Get.to(
            () => OutingChatPage(event: event),
            routeName: '/notification/outing/$id/chat',
          );
          return;
        }
        final section = switch (destination) {
          NotificationDestination.placeVoting =>
            OutingDetailsSection.placeVoting,
          NotificationDestination.attendance => OutingDetailsSection.attendance,
          _ => null,
        };
        Get.to(
          () => EventPage(event: event, initialSection: section),
          routeName: '/notification/outing/$id/${section?.name ?? ''}',
        );
      },
    );
  }
}
