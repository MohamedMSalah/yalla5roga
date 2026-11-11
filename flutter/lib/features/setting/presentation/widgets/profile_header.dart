import 'package:flutter/material.dart';
import 'package:yalla_5roga/core/theme/app_motion.dart';
import 'package:yalla_5roga/core/utils/extensions.dart';
import 'package:yalla_5roga/core/widgets/user_avatar.dart';
import 'package:yalla_5roga/features/auth/domain/entities/user.dart';

class ProfileHeader extends StatelessWidget {
  const ProfileHeader({
    super.key,
    required this.user,
    required this.onLogout,
    required this.onEditProfile,
  });

  final User? user;
  final VoidCallback onLogout;
  final VoidCallback onEditProfile;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final avatar = Responsive.avatarLg;
    final phone = (user?.phone ?? '').trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(l10n.navSettings, style: context.texts.headlineSmall),
            ),
            IconButton.outlined(
              tooltip: l10n.logOut,
              icon: const Icon(Icons.logout),
              onPressed: onLogout,
            ),
          ],
        ),
        Responsive.spaceMd.gapH,
        Row(
          children: [
            Semantics(
              button: true,
              label: l10n.editProfile,
              child: UserAvatar(
                url: user?.imageUrl ?? '',
                size: avatar,
                heroTag: HeroTags.profileAvatar,
                onTap: onEditProfile,
              ),
            ),
            Responsive.spaceMd.gapW,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(user?.name ?? '', style: context.texts.titleLarge),
                  if (phone.isNotEmpty)
                    Text(
                      l10n.digits(phone),
                      style: context.texts.bodyMedium?.copyWith(
                        color: context.palette.textMuted,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}
