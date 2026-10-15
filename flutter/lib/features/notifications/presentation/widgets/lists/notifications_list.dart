import 'package:flutter/material.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/core/widgets/app_empty_state.dart';
import 'package:yalla_5roga/features/notifications/domain/entities/notification_item.dart';
import 'package:yalla_5roga/features/notifications/presentation/providers/notifications_provider.dart';
import 'package:yalla_5roga/features/notifications/presentation/widgets/cards/notification_card.dart';

/// Notifications feed: today / earlier titles + cards / empty state.
class NotificationsList extends StatelessWidget {
  const NotificationsList({
    super.key,
    required this.items,
    required this.unreadOnly,
    required this.onOpen,
  });

  final List<NotificationItem> items;
  final bool unreadOnly;
  final ValueChanged<NotificationItem> onOpen;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    if (items.isEmpty) {
      return AppEmptyState(
        icon: unreadOnly
            ? Icons.mark_email_read_outlined
            : Icons.notifications_none_outlined,
        message: unreadOnly ? l10n.noUnreadNotifications : l10n.noNotifications,
        subtitle: unreadOnly
            ? l10n.noUnreadNotificationsHint
            : l10n.noNotificationsHint,
        compact: true,
      );
    }

    final today = NotificationsProvider.todayFrom(items);
    final earlier = NotificationsProvider.earlierFrom(items);
    final entries = <_NotificationEntry>[
      if (today.isNotEmpty) ...[
        _NotificationEntry.header(l10n.today.toUpperCase()),
        for (final item in today)
          _NotificationEntry.item(item, showAction: true),
      ],
      if (earlier.isNotEmpty) ...[
        _NotificationEntry.header(
          l10n.earlier.toUpperCase(),
          topGap: today.isNotEmpty,
        ),
        for (final item in earlier) _NotificationEntry.item(item),
      ],
    ];

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final entry = entries[index];
        if (entry.isHeader) {
          return Padding(
            padding: EdgeInsets.only(
              top: entry.topGap ? Responsive.spaceLg : 0,
              bottom: Responsive.spaceSm,
            ),
            child: Text(
              entry.header!,
              style: TextStyle(
                color: context.palette.textMuted,
                fontSize: Responsive.fontCaption,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.4,
              ),
            ),
          );
        }

        final item = entry.item!;
        return Padding(
          padding: EdgeInsets.only(bottom: 10.h),
          child: NotificationCard(
            body: item.body,
            time: item.time,
            unread: item.unread,
            image: item.image,
            actionLabel: entry.showAction && item.action ? l10n.voteNow : null,
            onAction: entry.showAction && item.action
                ? () => onOpen(item)
                : null,
            onTap: () => onOpen(item),
          ),
        );
      },
    );
  }
}

class _NotificationEntry {
  const _NotificationEntry._({
    this.header,
    this.item,
    this.showAction = false,
    this.topGap = false,
  });

  factory _NotificationEntry.header(String label, {bool topGap = false}) {
    return _NotificationEntry._(header: label, topGap: topGap);
  }

  factory _NotificationEntry.item(
    NotificationItem item, {
    bool showAction = false,
  }) {
    return _NotificationEntry._(item: item, showAction: showAction);
  }

  final String? header;
  final NotificationItem? item;
  final bool showAction;
  final bool topGap;

  bool get isHeader => header != null;
}
