import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:yalla_5roga/core/theme/app_colors.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/core/widgets/app_icon_button.dart';
import 'package:yalla_5roga/core/widgets/app_snackbar.dart';
import 'package:yalla_5roga/core/widgets/custom_button.dart';
import 'package:yalla_5roga/core/widgets/segmented_tabs.dart';
import 'package:yalla_5roga/features/groups/presentation/pages/group_details_page.dart';
import 'package:yalla_5roga/features/notifications/domain/entities/notification_item.dart';
import 'package:yalla_5roga/features/notifications/presentation/widgets/lists/notifications_list.dart';
import 'package:yalla_5roga/features/notifications/presentation/providers/notifications_provider.dart';
import 'package:yalla_5roga/features/notifications/presentation/widgets/notifications_skeleton.dart';
import 'package:yalla_5roga/features/outings/presentation/pages/event_page.dart';
import 'package:yalla_5roga/features/outings/presentation/providers/outings_provider.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  var _markedOnOpen = false;
  NotificationsProvider? _notifications;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _notifications = context.read<NotificationsProvider>();
      _notifications!.addListener(_markAllWhenReady);
      _markAllWhenReady();
    });
  }

  @override
  void dispose() {
    _notifications?.removeListener(_markAllWhenReady);
    super.dispose();
  }

  void _markAllWhenReady() {
    final notifications = _notifications;
    if (!mounted ||
        notifications == null ||
        _markedOnOpen ||
        !notifications.hasLoaded)
      return;
    _markedOnOpen = true;
    notifications.removeListener(_markAllWhenReady);
    notifications.markAllRead();
  }

  Future<void> _open(NotificationItem item) async {
    final notifications = context.read<NotificationsProvider>();
    if (item.unread) {
      final marked = await notifications.markRead(item.id);
      if (!marked || !mounted) return;
    }
    if (item.outingId != null) {
      final outing = context.read<OutingsProvider>().byId(item.outingId!);
      Get.to(() => EventPage(event: outing));
      return;
    }
    if (item.groupId != null) {
      Get.to(() => GroupDetailsPage(groupId: item.groupId!));
    }
  }

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
        child: RefreshIndicator(
          color: AppColors.brand600,
          onRefresh: () => notifications.refresh(forceRefresh: true),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
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
      ),
    );
  }
}
