import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/core/widgets/app_icon_button.dart';
import 'package:yalla_5roga/features/notifications/presentation/pages/notifications_page.dart';
import 'package:yalla_5roga/features/notifications/presentation/providers/notifications_provider.dart';

class NotificationButton extends StatelessWidget {
  const NotificationButton({super.key, this.showUnreadDot = false, this.size});

  final bool showUnreadDot;
  final double? size;

  @override
  Widget build(BuildContext context) {
    void openNotifications() => Get.to(() => const NotificationsPage());
    final l10n = context.l10n;
    final tooltip = l10n.notifications;

    if (!showUnreadDot) {
      final unread = context.select((NotificationsProvider p) => p.unreadCount);
      return AppIconButton(
        icon: Icons.notifications_none_rounded,
        tooltip: tooltip,
        badgeColor: const Color(0xFF8444D7),
        badge: unread == 0 ? null : l10n.n(unread),
        onTap: openNotifications,
      );
    }

    final hasUnread = context.select(
      (NotificationsProvider p) => p.unreadCount > 0,
    );
    final palette = context.palette;
    final styled = size != null;
    final targetSize = size ?? 48;
    return Stack(
      alignment: Alignment.center,
      children: [
        IgnorePointer(
          child: Container(
            width: size ?? 44,
            height: size ?? 44,
            decoration: BoxDecoration(
              color: styled
                  ? palette.surface
                  : palette.surfaceMuted.withValues(alpha: .68),
              borderRadius: BorderRadius.circular(styled ? 17 : 13),
              border: Border.all(
                color: styled ? palette.border : palette.brandSoftBorder,
              ),
            ),
          ),
        ),
        IconButton(
          onPressed: openNotifications,
          tooltip: hasUnread ? '$tooltip (${l10n.unread})' : tooltip,
          icon: const Icon(Icons.notifications_none_rounded),
          iconSize: 23,
          color: palette.textSecondary,
          constraints: BoxConstraints.tightFor(
            width: targetSize,
            height: targetSize,
          ),
        ),
        if (hasUnread)
          PositionedDirectional(
            top: 8,
            end: 8,
            child: IgnorePointer(
              child: Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  color: palette.isDark
                      ? const Color(0xFFB778F2)
                      : palette.brandStrong,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
