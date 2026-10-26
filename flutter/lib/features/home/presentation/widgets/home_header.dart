import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/core/widgets/notification_button.dart';
import 'package:yalla_5roga/core/widgets/user_avatar.dart';
import 'package:yalla_5roga/features/auth/presentation/providers/auth_provider.dart';

class HomeHeader extends StatelessWidget {
  const HomeHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final user = context.watch<AuthProvider>().user;
    final avatar = Responsive.avatarMd;
    final photo = user?.imageUrl ?? '';

    return Row(
      children: [
        UserAvatar(url: photo, size: avatar),
        12.gapW,
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.greetingForHour(DateTime.now().hour),
                style: TextStyle(
                  color: context.palette.textMuted,
                  fontSize: Responsive.fontSm,
                ),
              ),
              Text(
                '${user?.name.split(' ').first ?? ''} 👋',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15.sp),
              ),
            ],
          ),
        ),
        const NotificationButton(),
      ],
    );
  }
}
