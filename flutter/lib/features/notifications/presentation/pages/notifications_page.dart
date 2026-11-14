import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/core/widgets/app_page_bar.dart';
import 'package:yalla_5roga/core/widgets/app_error_state.dart';
import 'package:yalla_5roga/core/widgets/app_snackbar.dart';
import 'package:yalla_5roga/core/widgets/custom_button.dart';
import 'package:yalla_5roga/core/widgets/filter_chip_row.dart';
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
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<NotificationsProvider>().refresh();
    });
  }

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
    return Scaffold(
      appBar: AppPageBar(
        title: l10n.notifications,
        subtitle: l10n.unreadUpdates(unreadCount),
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: Responsive.contentMaxWidth),
            child: Column(
              children: [
                Padding(
                  padding: Responsive.pagePadding().copyWith(top: 0, bottom: 8),
                  child: Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      FilterChipRow(
                        labels: [
                          l10n.all,
                          '${l10n.unread} (${l10n.n(unreadCount)})',
                        ],
                        index: notifications.filter,
                        onChanged: notifications.setFilter,
                      ),
                      CustomButton(
                        label: unreadCount == 0
                            ? l10n.allRead
                            : l10n.markAllRead,
                        size: AppButtonSize.small,
                        expand: false,
                        variant: AppButtonVariant.light,
                        isLoading: notifications.isUpdating,
                        onPressed: unreadCount == 0 ? null : _markAll,
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: notifications.isLoading && notifications.items.isEmpty
                      ? const NotificationsSkeleton()
                      : notifications.errorMessage != null &&
                            notifications.items.isEmpty
                      ? AppErrorState(
                          message: notifications.errorMessage!,
                          onRetry: () =>
                              notifications.refresh(forceRefresh: true),
                        )
                      : ListView(
                          padding: Responsive.pagePadding(),
                          children: [
                            if (notifications.errorMessage != null)
                              AppErrorState(
                                message: notifications.errorMessage!,
                                onRetry: () =>
                                    notifications.refresh(forceRefresh: true),
                              ),
                            NotificationsList(
                              items: notifications.visible,
                              unreadOnly: notifications.filter == 1,
                              onOpen: _open,
                            ),
                          ],
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
