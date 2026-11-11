import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/core/widgets/app_icon_button.dart';
import 'package:yalla_5roga/core/widgets/app_snackbar.dart';
import 'package:yalla_5roga/core/widgets/custom_button.dart';
import 'package:yalla_5roga/core/widgets/segmented_tabs.dart';
import 'package:yalla_5roga/features/notifications/domain/entities/notification_item.dart';
import 'package:yalla_5roga/features/notifications/presentation/providers/fcm_provider.dart';
import 'package:yalla_5roga/features/notifications/presentation/widgets/lists/notifications_list.dart';
import 'package:yalla_5roga/features/notifications/presentation/providers/notifications_provider.dart';
import 'package:yalla_5roga/features/notifications/presentation/widgets/notifications_skeleton.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  Future<void> _open(NotificationItem item) =>
      context.read<FcmProvider>().openInboxItem(item);

  Future<void> _markAll() async {
    final l10n = context.l10n;
    final marked = await context.read<NotificationsProvider>().markAllRead();
    if (marked && mounted) {
      AppSnackBar.show(l10n.allNotificationsRead);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final notifications = context.watch<NotificationsProvider>();
    final unreadCount = notifications.unreadCount;
    final unread = notifications.items.where((item) => item.unread).toList();

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: Responsive.pagePadding(),
          children: [
            Row(
              children: [
                AppIconButton(icon: context.chevronBack, onTap: Get.back),
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        l10n.notifications,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: Responsive.fontMd,
                        ),
                      ),
                      Text(
                        l10n.unreadUpdates(unreadCount),
                        style: TextStyle(
                          color: context.palette.textMuted,
                          fontSize: 10.sp,
                        ),
                      ),
                    ],
                  ),
                ),
                CustomButton(
                  label: unreadCount == 0 ? l10n.allRead : l10n.markAllRead,
                  size: AppButtonSize.small,
                  expand: false,
                  variant: AppButtonVariant.light,
                  isLoading: notifications.isUpdating,
                  onPressed: unreadCount == 0 ? null : _markAll,
                ),
              ],
            ),
            Responsive.spaceMd.gapH,
            SegmentedTabs(
              labels: [l10n.all, l10n.unread],
              index: notifications.filter,
              onChanged: notifications.setFilter,
              badges: {1: l10n.n(unreadCount)},
              children: [
                if (notifications.isInitialLoading ||
                    (notifications.isLoading && notifications.items.isEmpty))
                  const NotificationsSkeleton()
                else
                  NotificationsList(
                    items: notifications.items,
                    unreadOnly: false,
                    onOpen: _open,
                  ),
                if (notifications.isInitialLoading ||
                    (notifications.isLoading && notifications.items.isEmpty))
                  const NotificationsSkeleton()
                else
                  NotificationsList(
                    items: unread,
                    unreadOnly: true,
                    onOpen: _open,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
