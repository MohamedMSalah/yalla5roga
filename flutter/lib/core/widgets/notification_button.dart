import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:yalla_5roga/core/widgets/app_icon_button.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/features/notifications/presentation/pages/notifications_page.dart';
import 'package:yalla_5roga/features/notifications/presentation/providers/notifications_provider.dart';

class NotificationButton extends StatelessWidget {
  const NotificationButton({super.key});

  @override
  Widget build(BuildContext context) {
    final unread = context.watch<NotificationsProvider>().unreadCount;
    return AppIconButton(
      icon: Icons.notifications_none_rounded,
      badge: unread == 0 ? null : context.l10n.n(unread),
      onTap: () => Get.to(() => const NotificationsPage()),
    );
  }
}
